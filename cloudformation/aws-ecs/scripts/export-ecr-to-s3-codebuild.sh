#!/bin/bash
# Export ECR images to S3 using an inline CodeBuild job
# This runs in the AWS account and doesn't require local Docker
#
# Usage: ./export-ecr-to-s3-codebuild.sh [OPTIONS]
#
# Options:
#   -b, --bucket BUCKET     S3 bucket name (default: mcp-gateway-images-export-<account-id>)
#   -p, --prefix PREFIX     S3 prefix (default: mcp-gateway/v1.0.8)
#   -r, --region REGION     AWS region (default: us-west-2)
#   -i, --images "IMG1 IMG2" Space-separated list of image names to export
#                           (default: all mcp-gateway images)
#   -t, --tag TAG           Image tag to use for all images (default: v1.0.8)
#
# Examples:
#   # Export all default images with default tag
#   ./export-ecr-to-s3-codebuild.sh
#
#   # Export specific images
#   ./export-ecr-to-s3-codebuild.sh -i "mcp-gateway-keycloak"
#   ./export-ecr-to-s3-codebuild.sh -i "mcp-gateway-registry mcp-gateway-auth-server"
#
#   # Export only changed images for v1.0.8 (registry and mcpgw)
#   ./export-ecr-to-s3-codebuild.sh -i "mcp-gateway-registry mcp-gateway-mcpgw" -t v1.0.8
#
#   # Custom bucket and prefix
#   ./export-ecr-to-s3-codebuild.sh -b my-bucket -p images/v2.0.0 -i "mcp-gateway-keycloak"

set -e

# Default values - dynamically set based on environment
DEFAULT_IMAGES="mcp-gateway-registry mcp-gateway-auth-server mcp-gateway-currenttime mcp-gateway-mcpgw mcp-gateway-realserverfaketools mcp-gateway-flight-booking-agent mcp-gateway-travel-assistant-agent mcp-gateway-keycloak"
DEFAULT_TAG="v1.0.8"

REGION="us-west-2"
S3_BUCKET=""  # Will be set dynamically if not provided
S3_PREFIX=""  # Will be set dynamically if not provided
IMAGES=""
IMAGE_TAG=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--bucket)
      S3_BUCKET="$2"
      shift 2
      ;;
    -p|--prefix)
      S3_PREFIX="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -i|--images)
      IMAGES="$2"
      shift 2
      ;;
    -t|--tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    -h|--help)
      head -30 "$0" | tail -27
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Get account ID first (needed for dynamic defaults)
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text --region $REGION)

# Set dynamic defaults if not provided
if [ -z "$S3_BUCKET" ]; then
  S3_BUCKET="mcp-gateway-images-export-${ACCOUNT_ID}"
fi

if [ -z "$IMAGE_TAG" ]; then
  IMAGE_TAG="$DEFAULT_TAG"
fi

if [ -z "$S3_PREFIX" ]; then
  S3_PREFIX="mcp-gateway/${IMAGE_TAG}"
fi

# Use default images if none specified
if [ -z "$IMAGES" ]; then
  IMAGES="$DEFAULT_IMAGES"
fi

# Build the images list with tags
IMAGES_WITH_TAGS=""
for IMG in $IMAGES; do
  # If image already has a tag (contains :), use as-is, otherwise append default tag
  if [[ "$IMG" == *":"* ]]; then
    IMAGES_WITH_TAGS="$IMAGES_WITH_TAGS $IMG"
  else
    IMAGES_WITH_TAGS="$IMAGES_WITH_TAGS ${IMG}:${IMAGE_TAG}"
  fi
done
IMAGES_WITH_TAGS=$(echo "$IMAGES_WITH_TAGS" | xargs)  # Trim whitespace
PROJECT_NAME="ecr-export-temp-$(date +%s)"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "=============================================="
echo "ECR to S3 Export via CodeBuild"
echo "=============================================="
echo "Account:    $ACCOUNT_ID"
echo "Region:     $REGION"
echo "S3 Bucket:  $S3_BUCKET"
echo "S3 Prefix:  $S3_PREFIX"
echo "Project:    $PROJECT_NAME"
echo "Image Tag:  $IMAGE_TAG"
echo "Images:     $IMAGES_WITH_TAGS"
echo "=============================================="

# Check if S3 bucket exists, create if not
echo ""
echo "Checking S3 bucket..."
if aws s3api head-bucket --bucket "$S3_BUCKET" --region $REGION 2>/dev/null; then
  echo "✓ S3 bucket exists: $S3_BUCKET"
else
  echo "Creating S3 bucket: $S3_BUCKET"
  if [ "$REGION" = "us-east-1" ]; then
    # us-east-1 doesn't support LocationConstraint
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --region $REGION
  else
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --region $REGION \
      --create-bucket-configuration LocationConstraint=$REGION
  fi
  
  # Enable versioning for safety
  aws s3api put-bucket-versioning \
    --bucket "$S3_BUCKET" \
    --versioning-configuration Status=Enabled \
    --region $REGION
  
  # Block public access
  aws s3api put-public-access-block \
    --bucket "$S3_BUCKET" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region $REGION
  
  echo "✓ S3 bucket created with versioning enabled and public access blocked"
fi

# Create IAM role for CodeBuild
ROLE_NAME="ecr-export-codebuild-role-$$"
POLICY_NAME="ecr-export-policy-$$"

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
  --region $REGION > /dev/null

# Policy for ECR read, S3 write, CloudWatch logs
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
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${S3_BUCKET}",
        "arn:aws:s3:::${S3_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
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

# Wait for role to propagate
echo "Waiting for IAM role to propagate..."
sleep 10

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Create CodeBuild project with inline buildspec
echo ""
echo "Creating CodeBuild project..."

# Create buildspec file
cat > /tmp/buildspec.yml << 'BUILDSPEC'
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to ECR...
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
  build:
    commands:
      - echo Starting image export...
      - echo "Images to export - $IMAGES_LIST"
      - mkdir -p /tmp/images
      - |
        for ITEM in $IMAGES_LIST; do
          # Support image:tag format, default to :latest if no tag specified
          if [[ "$ITEM" == *":"* ]]; then
            IMAGE="${ITEM%%:*}"
            TAG="${ITEM##*:}"
          else
            IMAGE="$ITEM"
            TAG="latest"
          fi
          FULL_NAME="${IMAGE}:${TAG}"
          SAFE_NAME="${IMAGE}-${TAG}"
          echo "Processing $FULL_NAME..."
          docker pull $ECR_REGISTRY/$FULL_NAME || { echo "Failed to pull $FULL_NAME, skipping"; continue; }
          echo "Saving and splitting $FULL_NAME into <1GB parts..."
          docker save $ECR_REGISTRY/$FULL_NAME | gzip | split -b 900M - /tmp/images/${SAFE_NAME}.tar.gz.part_
          for PART in /tmp/images/${SAFE_NAME}.tar.gz.part_*; do
            PARTNAME=$(basename $PART)
            aws s3 cp $PART s3://$S3_BUCKET/$S3_PREFIX/$PARTNAME
            echo "Uploaded $PARTNAME"
            rm $PART
          done
          echo "Uploaded all parts for $FULL_NAME"
        done
  post_build:
    commands:
      - echo Export complete!
      - aws s3 ls s3://$S3_BUCKET/$S3_PREFIX/
BUILDSPEC

# Use jq to properly escape the buildspec for JSON
BUILDSPEC_CONTENT=$(jq -Rs '.' /tmp/buildspec.yml)

cat > /tmp/codebuild-project.json << EOF
{
  "name": "${PROJECT_NAME}",
  "description": "Temporary project to export ECR images to S3",
  "source": {
    "type": "NO_SOURCE",
    "buildspec": ${BUILDSPEC_CONTENT}
  },
  "artifacts": {
    "type": "NO_ARTIFACTS"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/amazonlinux2-x86_64-standard:5.0",
    "computeType": "BUILD_GENERAL1_MEDIUM",
    "privilegedMode": true,
    "environmentVariables": [
      {"name": "AWS_REGION", "value": "${REGION}"},
      {"name": "ECR_REGISTRY", "value": "${ECR_REGISTRY}"},
      {"name": "S3_BUCKET", "value": "${S3_BUCKET}"},
      {"name": "S3_PREFIX", "value": "${S3_PREFIX}"},
      {"name": "IMAGES_LIST", "value": "${IMAGES_WITH_TAGS}"}
    ]
  },
  "serviceRole": "${ROLE_ARN}",
  "timeoutInMinutes": 30
}
EOF

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
echo "Monitoring build progress..."

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
  
  sleep 10
done

echo ""
echo "=============================================="
if [ "$STATUS" = "SUCCEEDED" ]; then
  echo "✅ Build completed successfully!"
  echo ""
  echo "Images exported to: s3://${S3_BUCKET}/${S3_PREFIX}/"
  echo ""
  echo "Listing exported files:"
  aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" --region $REGION
else
  echo "❌ Build failed with status: $STATUS"
  echo ""
  echo "Check CloudWatch logs for details:"
  echo "  Log group: /aws/codebuild/${PROJECT_NAME}"
fi
echo "=============================================="

# Cleanup
echo ""
echo "Cleaning up temporary resources..."

aws codebuild delete-project --name "$PROJECT_NAME" --region $REGION 2>/dev/null || true
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME" --region $REGION 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" --region $REGION 2>/dev/null || true

rm -f /tmp/trust-policy.json /tmp/policy.json /tmp/codebuild-project.json /tmp/buildspec.yml

echo "Cleanup complete."
echo ""
echo "To download image chunks locally:"
echo "  aws s3 sync s3://${S3_BUCKET}/${S3_PREFIX}/ ./workshop-images/ --region $REGION"
echo ""
echo "Files are split into <1GB chunks (e.g., mcp-gateway-registry.tar.gz.part_aa, part_ab, etc.)"
echo ""
echo "To reassemble later (when needed for docker load):"
echo "  cat IMAGE.tar.gz.part_* > IMAGE.tar.gz"
echo "  gunzip -c IMAGE.tar.gz | docker load"
