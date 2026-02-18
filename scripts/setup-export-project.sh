#!/usr/bin/env bash
# Create a CodeBuild project in your personal AWS account for building
# and exporting container images as tarballs to S3.
#
# Run once. After this, use export-containers.sh to trigger builds.
#
# What it creates:
#   1. S3 bucket for tarball storage (if it doesn't exist)
#   2. IAM role for CodeBuild (ECR read, S3 write, CloudWatch Logs)
#   3. CodeBuild project pointing to your GitHub fork
#
# Prerequisites:
#   - AWS CLI configured with a profile that has IAM + CodeBuild + S3 permissions
#   - GitHub repo must be connected to CodeBuild in the AWS console (one-time OAuth)
#     If not, the script will tell you how to do it.
#
# Usage:
#   ./scripts/setup-export-project.sh
#
# Environment variables (override defaults):
#   AWS_PROFILE_BUILD  - AWS CLI profile (default: personal)
#   AWS_REGION         - region (default: us-west-2)
#   GITHUB_REPO_URL    - fork URL (default: https://github.com/WPrintz/mcp-gateway-registry.git)

set -euo pipefail

AWS_PROFILE_BUILD="${AWS_PROFILE_BUILD:-printw-Admin}"
AWS_REGION="${AWS_REGION:-us-east-1}"
GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/WPrintz/mcp-gateway-registry.git}"

PROJECT_NAME="mcp-gateway-export-containers"
ROLE_NAME="mcp-gateway-export-codebuild-role"

# Derive account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE_BUILD" --query 'Account' --output text)
S3_BUCKET="mcp-gateway-codebuild-cache-${ACCOUNT_ID}"

echo "=== Setup Export CodeBuild Project ==="
echo "  Account:  $ACCOUNT_ID"
echo "  Profile:  $AWS_PROFILE_BUILD"
echo "  Region:   $AWS_REGION"
echo "  Project:  $PROJECT_NAME"
echo "  S3:       $S3_BUCKET"
echo "  GitHub:   $GITHUB_REPO_URL"
echo ""

# ── 1. S3 Bucket ──────────────────────────────────────────────────────────────
echo "Step 1: S3 bucket..."
if aws s3api head-bucket --bucket "$S3_BUCKET" --profile "$AWS_PROFILE_BUILD" --region "$AWS_REGION" 2>/dev/null; then
  echo "  Bucket $S3_BUCKET already exists."
else
  echo "  Creating bucket $S3_BUCKET..."
  aws s3api create-bucket \
    --bucket "$S3_BUCKET" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION" \
    --profile "$AWS_PROFILE_BUILD"
  echo "  Created."
fi

# ── 2. IAM Role ───────────────────────────────────────────────────────────────
echo "Step 2: IAM role..."
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

if aws iam get-role --role-name "$ROLE_NAME" --profile "$AWS_PROFILE_BUILD" 2>/dev/null; then
  echo "  Role $ROLE_NAME already exists."
else
  echo "  Creating role $ROLE_NAME..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --profile "$AWS_PROFILE_BUILD" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "codebuild.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }]
    }'

  aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "ExportContainersPolicy" \
    --profile "$AWS_PROFILE_BUILD" \
    --policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Effect\": \"Allow\",
          \"Action\": [
            \"logs:CreateLogGroup\",
            \"logs:CreateLogStream\",
            \"logs:PutLogEvents\"
          ],
          \"Resource\": \"arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:/aws/codebuild/${PROJECT_NAME}*\"
        },
        {
          \"Effect\": \"Allow\",
          \"Action\": [
            \"ecr:GetAuthorizationToken\"
          ],
          \"Resource\": \"*\"
        },
        {
          \"Effect\": \"Allow\",
          \"Action\": [
            \"ecr:BatchCheckLayerAvailability\",
            \"ecr:GetDownloadUrlForLayer\",
            \"ecr:BatchGetImage\"
          ],
          \"Resource\": \"arn:aws:ecr:${AWS_REGION}:${ACCOUNT_ID}:repository/*\"
        },
        {
          \"Effect\": \"Allow\",
          \"Action\": [
            \"s3:PutObject\",
            \"s3:GetObject\",
            \"s3:ListBucket\"
          ],
          \"Resource\": [
            \"arn:aws:s3:::${S3_BUCKET}\",
            \"arn:aws:s3:::${S3_BUCKET}/*\"
          ]
        }
      ]
    }"

  echo "  Created. Waiting 10s for IAM propagation..."
  sleep 10
fi

# ── 3. CodeBuild Project ──────────────────────────────────────────────────────
echo "Step 3: CodeBuild project..."
if aws codebuild batch-get-projects --names "$PROJECT_NAME" --profile "$AWS_PROFILE_BUILD" --region "$AWS_REGION" \
    --query 'projects[0].name' --output text 2>/dev/null | grep -q "$PROJECT_NAME"; then
  echo "  Project $PROJECT_NAME already exists."
else
  echo "  Creating project $PROJECT_NAME..."
  aws codebuild create-project \
    --name "$PROJECT_NAME" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE_BUILD" \
    --source "{
      \"type\": \"GITHUB\",
      \"location\": \"${GITHUB_REPO_URL}\",
      \"buildspec\": \"scripts/codebuild/buildspec-export.yaml\"
    }" \
    --artifacts '{"type": "NO_ARTIFACTS"}' \
    --environment "{
      \"type\": \"LINUX_CONTAINER\",
      \"computeType\": \"BUILD_GENERAL1_LARGE\",
      \"image\": \"aws/codebuild/amazonlinux2-x86_64-standard:5.0\",
      \"privilegedMode\": true,
      \"environmentVariables\": [
        {\"name\": \"AWS_REGION\", \"value\": \"${AWS_REGION}\"},
        {\"name\": \"ECR_REGISTRY\", \"value\": \"${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com\"},
        {\"name\": \"IMAGE_TAG\", \"value\": \"v1.0.12\"},
        {\"name\": \"S3_DEST_BUCKET\", \"value\": \"${S3_BUCKET}\"},
        {\"name\": \"S3_DEST_PREFIX\", \"value\": \"container-exports\"}
      ]
    }" \
    --service-role "$ROLE_ARN" \
    --timeout-in-minutes 45 \
    --query 'project.name' --output text

  if [ $? -ne 0 ]; then
    echo ""
    echo "  If you got a 'repository not found' error, you need to connect GitHub first:"
    echo "  1. Go to: https://${AWS_REGION}.console.aws.amazon.com/codesuite/codebuild/projects"
    echo "  2. Click 'Create build project'"
    echo "  3. Under Source, select GitHub and click 'Connect using OAuth'"
    echo "  4. Authorize AWS CodeBuild, then cancel the project creation"
    echo "  5. Re-run this script"
    exit 1
  fi
  echo "  Created."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To trigger an export build:"
echo "  ./scripts/export-containers.sh"
echo ""
echo "To trigger and download tarballs locally:"
echo "  ./scripts/export-containers.sh --download"
echo ""
