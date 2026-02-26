#!/bin/bash
# Build CPU-only mcpgw image and export to S3
set -e

REGION=${1:-us-west-2}
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text --region $REGION)
PROJECT_NAME="mcpgw-cpu-build-$(date +%s)"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
S3_BUCKET="mcp-gateway-images-export-${ACCOUNT_ID}"
S3_PREFIX="mcp-gateway/v1.0.6"

echo "=============================================="
echo "Build CPU-only mcpgw Image via CodeBuild"
echo "=============================================="
echo "Account:    $ACCOUNT_ID"
echo "Region:     $REGION"
echo "=============================================="

# Reuse existing IAM role
ROLE_NAME="image-compare-codebuild-role"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Upload source to S3
SOURCE_BUCKET="codebuild-source-${ACCOUNT_ID}-${REGION}"
echo "Uploading source code to S3..."
cd "$(git rev-parse --show-toplevel)"
git archive --format=zip HEAD -o /tmp/source.zip
aws s3 cp /tmp/source.zip "s3://${SOURCE_BUCKET}/mcp-gateway-source.zip" --region $REGION
rm /tmp/source.zip

# Create buildspec
cat > /tmp/buildspec.yml << 'EOF'
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to ECR...
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
  build:
    commands:
      - echo Building CPU-only mcpgw image...
      - docker build -f docker/Dockerfile.mcp-server-cpu --build-arg SERVER_DIR=servers/mcpgw -t mcp-gateway-mcpgw:cpu-only .
      - docker images | grep mcpgw
  post_build:
    commands:
      - echo Pushing to ECR...
      - docker tag mcp-gateway-mcpgw:cpu-only $ECR_REGISTRY/mcp-gateway-mcpgw:cpu-only
      - docker push $ECR_REGISTRY/mcp-gateway-mcpgw:cpu-only
      - echo Exporting to S3...
      - mkdir -p /tmp/images
      - docker save $ECR_REGISTRY/mcp-gateway-mcpgw:cpu-only | gzip | split -b 900M - /tmp/images/mcp-gateway-mcpgw-cpu-only.tar.gz.part_
      - for PART in /tmp/images/mcp-gateway-mcpgw-cpu-only.tar.gz.part_*; do PARTNAME=$(basename $PART); aws s3 cp $PART s3://$S3_BUCKET/$S3_PREFIX/$PARTNAME; echo "Uploaded $PARTNAME"; done
      - echo Done!
      - aws s3 ls s3://$S3_BUCKET/$S3_PREFIX/ | grep mcpgw
EOF

BUILDSPEC_CONTENT=$(jq -Rs '.' /tmp/buildspec.yml)

cat > /tmp/codebuild-project.json << EOF
{
  "name": "${PROJECT_NAME}",
  "description": "Build CPU-only mcpgw image",
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
      {"name": "ECR_REGISTRY", "value": "${ECR_REGISTRY}"},
      {"name": "S3_BUCKET", "value": "${S3_BUCKET}"},
      {"name": "S3_PREFIX", "value": "${S3_PREFIX}"}
    ]
  },
  "serviceRole": "${ROLE_ARN}",
  "timeoutInMinutes": 60
}
EOF

echo "Creating CodeBuild project..."
aws codebuild create-project --cli-input-json file:///tmp/codebuild-project.json --region $REGION > /dev/null

echo "Starting build..."
BUILD_ID=$(aws codebuild start-build --project-name "$PROJECT_NAME" --region $REGION --query 'build.id' --output text)
echo "Build started: $BUILD_ID"

echo "Monitoring build progress..."
while true; do
  STATUS=$(aws codebuild batch-get-builds --ids "$BUILD_ID" --region $REGION --query 'builds[0].buildStatus' --output text)
  PHASE=$(aws codebuild batch-get-builds --ids "$BUILD_ID" --region $REGION --query 'builds[0].currentPhase' --output text)
  echo "  Status: $STATUS | Phase: $PHASE"
  if [ "$STATUS" != "IN_PROGRESS" ]; then break; fi
  sleep 30
done

echo ""
if [ "$STATUS" = "SUCCEEDED" ]; then
  echo "✅ Build completed successfully!"
  echo ""
  echo "Comparing sizes:"
  ORIGINAL=$(aws ecr describe-images --repository-name mcp-gateway-mcpgw --image-ids imageTag=latest --region $REGION --query 'imageDetails[0].imageSizeInBytes' --output text 2>/dev/null || echo "0")
  CPU=$(aws ecr describe-images --repository-name mcp-gateway-mcpgw --image-ids imageTag=cpu-only --region $REGION --query 'imageDetails[0].imageSizeInBytes' --output text 2>/dev/null || echo "0")
  echo "  Original (latest): $(echo "scale=2; $ORIGINAL / 1024 / 1024 / 1024" | bc) GB"
  echo "  CPU-only:          $(echo "scale=2; $CPU / 1024 / 1024 / 1024" | bc) GB"
else
  echo "❌ Build failed: $STATUS"
  echo "Check logs: /aws/codebuild/${PROJECT_NAME}"
fi

echo ""
echo "Cleaning up..."
aws codebuild delete-project --name "$PROJECT_NAME" --region $REGION 2>/dev/null || true
rm -f /tmp/buildspec.yml /tmp/codebuild-project.json
echo "Done."
