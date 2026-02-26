#!/bin/bash
# Build CPU-only PyTorch variant and compare to existing image
#
# Usage: ./compare-image-sizes-codebuild.sh [REGION]

set -e

REGION=${1:-us-west-2}
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text --region $REGION)
PROJECT_NAME="image-cpu-build-$(date +%s)"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Get existing image size
ORIGINAL_SIZE=$(aws ecr describe-images --repository-name mcp-gateway-registry --region $REGION --query 'imageDetails[0].imageSizeInBytes' --output text)
ORIGINAL_SIZE_GB=$(echo "scale=2; $ORIGINAL_SIZE / 1024 / 1024 / 1024" | bc)

echo "=============================================="
echo "Build CPU-only PyTorch Image via CodeBuild"
echo "=============================================="
echo "Account:    $ACCOUNT_ID"
echo "Region:     $REGION"
echo "Project:    $PROJECT_NAME"
echo ""
echo "Existing mcp-gateway-registry: ${ORIGINAL_SIZE_GB} GB"
echo "=============================================="

# Create IAM role for CodeBuild
ROLE_NAME="image-compare-codebuild-role"
POLICY_NAME="image-compare-policy"

echo ""
echo "Creating IAM role..."

# Trust policy for CodeBuild
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --region $REGION 2>/dev/null || echo "Role already exists, reusing..."

# Policy for ECR and CloudWatch logs
cat > /tmp/policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": "arn:aws:s3:::codebuild-source-${ACCOUNT_ID}-${REGION}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPull"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document file:///tmp/policy.json \
  --region $REGION

echo "Waiting for IAM role to propagate..."
sleep 10

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Create S3 bucket for source if needed
SOURCE_BUCKET="codebuild-source-${ACCOUNT_ID}-${REGION}"
aws s3 mb "s3://${SOURCE_BUCKET}" --region $REGION 2>/dev/null || true

# Zip and upload source code
echo "Uploading source code to S3..."
cd "$(git rev-parse --show-toplevel)"
git archive --format=zip HEAD -o /tmp/source.zip
aws s3 cp /tmp/source.zip "s3://${SOURCE_BUCKET}/mcp-gateway-source.zip" --region $REGION
rm /tmp/source.zip

# Create buildspec - only build CPU variant
cat > /tmp/buildspec.yml << 'EOF'
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to ECR...
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
  build:
    commands:
      - echo Building CPU-ONLY PyTorch image...
      - docker build -f docker/Dockerfile.registry-cpu -t mcp-gateway-registry:cpu-only .
      - docker images | grep mcp-gateway
  post_build:
    commands:
      - echo Pushing to ECR...
      - docker tag mcp-gateway-registry:cpu-only $ECR_REGISTRY/mcp-gateway-registry:cpu-only
      - docker push $ECR_REGISTRY/mcp-gateway-registry:cpu-only
      - echo Done! Check ECR for size comparison.
EOF

# Use jq to properly escape the buildspec for JSON
BUILDSPEC_CONTENT=$(jq -Rs '.' /tmp/buildspec.yml)

cat > /tmp/codebuild-project.json << EOF
{
  "name": "${PROJECT_NAME}",
  "description": "Compare Docker image sizes - original vs CPU-only PyTorch",
  "source": {
    "type": "S3",
    "location": "${SOURCE_BUCKET}/mcp-gateway-source.zip",
    "buildspec": ${BUILDSPEC_CONTENT}
  },
  "artifacts": {
    "type": "NO_ARTIFACTS"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:5.0",
    "computeType": "BUILD_GENERAL1_LARGE",
    "privilegedMode": true,
    "environmentVariables": [
      {"name": "AWS_REGION", "value": "${REGION}"},
      {"name": "ECR_REGISTRY", "value": "${ECR_REGISTRY}"}
    ]
  },
  "serviceRole": "${ROLE_ARN}",
  "timeoutInMinutes": 60
}
EOF

echo ""
echo "Creating CodeBuild project..."
aws codebuild create-project \
  --cli-input-json file:///tmp/codebuild-project.json \
  --region $REGION > /dev/null

echo "CodeBuild project created: $PROJECT_NAME"

# Start the build
echo ""
echo "Starting build..."
BUILD_ID=$(aws codebuild start-build \
  --project-name "$PROJECT_NAME" \
  --region $REGION \
  --query 'build.id' \
  --output text)

echo "Build started: $BUILD_ID"
echo ""
echo "Monitoring build progress (this will take 15-30 minutes)..."

# Monitor build status
while true; do
  STATUS=$(aws codebuild batch-get-builds \
    --ids "$BUILD_ID" \
    --region $REGION \
    --query 'builds[0].buildStatus' \
    --output text)
  
  PHASE=$(aws codebuild batch-get-builds \
    --ids "$BUILD_ID" \
    --region $REGION \
    --query 'builds[0].currentPhase' \
    --output text)
  
  echo "  Status: $STATUS | Phase: $PHASE"
  
  if [ "$STATUS" != "IN_PROGRESS" ]; then
    break
  fi
  
  sleep 30
done

echo ""
echo "=============================================="
if [ "$STATUS" = "SUCCEEDED" ]; then
  echo "✅ Build completed successfully!"
  echo ""
  echo "Check CloudWatch logs for size comparison results:"
  echo "  Log group: /aws/codebuild/${PROJECT_NAME}"
  echo ""
  echo "Or check ECR image sizes:"
  echo "  aws ecr describe-images --repository-name mcp-registry-original --region $REGION --query 'imageDetails[0].imageSizeInBytes'"
  echo "  aws ecr describe-images --repository-name mcp-registry-cpu --region $REGION --query 'imageDetails[0].imageSizeInBytes'"
else
  echo "❌ Build failed with status: $STATUS"
  echo ""
  echo "Check CloudWatch logs for details:"
  echo "  Log group: /aws/codebuild/${PROJECT_NAME}"
fi
echo "=============================================="

# Cleanup
echo ""
echo "Cleaning up CodeBuild project..."
aws codebuild delete-project --name "$PROJECT_NAME" --region $REGION 2>/dev/null || true

rm -f /tmp/trust-policy.json /tmp/policy.json /tmp/codebuild-project.json /tmp/buildspec.yml

echo "Done."
