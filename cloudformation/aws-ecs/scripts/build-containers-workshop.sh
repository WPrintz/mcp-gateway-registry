#!/usr/bin/env bash
# Build container images from source via CodeBuild in the workshop account
# and push directly to workshop ECR. This is the "fast path" that bypasses
# the S3 tarball export pipeline.
#
# Overrides the existing mcp-gateway-container-build CodeBuild project
# (which normally uses NO_SOURCE + S3 tarballs) to instead pull source
# from GitHub and run scripts/codebuild/buildspec.yaml — the same
# buildspec used before the pre-built container pipeline was added.
#
# Requires workshop account credentials in the environment (source ws-creds.env).
# Does NOT use --profile.
#
# Usage:
#   ./cloudformation/aws-ecs/scripts/build-containers-workshop.sh
#   ./cloudformation/aws-ecs/scripts/build-containers-workshop.sh --branch main
#   ./cloudformation/aws-ecs/scripts/build-containers-workshop.sh --tag v1.0.16
#
# Environment variables (override defaults):
#   AWS_REGION           - region (default: us-west-2)
#   CODEBUILD_PROJECT    - CodeBuild project name (default: mcp-gateway-container-build)
#   IMAGE_TAG            - image tag (default: latest)
#   GITHUB_REPO_URL      - GitHub repo URL (default: https://github.com/WPrintz/mcp-gateway-registry.git)

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
CODEBUILD_PROJECT="${CODEBUILD_PROJECT:-mcp-gateway-container-build}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/WPrintz/mcp-gateway-registry.git}"
BRANCH=""


_usage() {
  sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$0"
  echo ""
  echo "Options:"
  echo "  -b, --branch BRANCH   Git branch to build from (default: current branch)"
  echo "  -t, --tag TAG         Image tag (default: latest)"
  echo "  -h, --help            Show this help"
}


_get_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main"
}


# --- Parse arguments ---
while [ $# -gt 0 ]; do
  case "$1" in
    -b|--branch)
      shift
      BRANCH="$1"
      ;;
    -t|--tag)
      shift
      IMAGE_TAG="$1"
      ;;
    -h|--help)
      _usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      _usage
      exit 1
      ;;
  esac
  shift
done

# Default to current branch
if [ -z "$BRANCH" ]; then
  BRANCH=$(_get_current_branch)
fi

# Verify AWS credentials are available (no --profile)
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null) || {
  echo "ERROR: No AWS credentials found in environment."
  echo "Source your workshop credentials first:"
  echo "  source ws-creds.env"
  exit 1
}
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=== Workshop Container Build (Fast Path) ==="
echo "  Account:    $ACCOUNT_ID"
echo "  Region:     $AWS_REGION"
echo "  Project:    $CODEBUILD_PROJECT"
echo "  Branch:     $BRANCH"
echo "  Image tag:  $IMAGE_TAG"
echo "  ECR:        $ECR_REGISTRY"
echo "  Buildspec:  scripts/codebuild/buildspec.yaml (from repo)"
echo ""

# Start CodeBuild with source override pointing to GitHub.
# The repo contains scripts/codebuild/buildspec.yaml which builds all 10
# images from Dockerfiles and pushes to ECR — the same flow used before
# the pre-built container pipeline (commit a85f2ee).
BUILD_ID=$(aws codebuild start-build \
  --project-name "$CODEBUILD_PROJECT" \
  --region "$AWS_REGION" \
  --source-type-override GITHUB \
  --source-location-override "$GITHUB_REPO_URL" \
  --source-version "$BRANCH" \
  --buildspec-override scripts/codebuild/buildspec.yaml \
  --environment-variables-override \
    "[{\"name\":\"IMAGE_TAG\",\"value\":\"$IMAGE_TAG\",\"type\":\"PLAINTEXT\"},
      {\"name\":\"ECR_REGISTRY\",\"value\":\"$ECR_REGISTRY\",\"type\":\"PLAINTEXT\"},
      {\"name\":\"AWS_REGION\",\"value\":\"$AWS_REGION\",\"type\":\"PLAINTEXT\"}]" \
  --query 'build.id' --output text)

echo "Build started: $BUILD_ID"

BUILD_URL="https://${AWS_REGION}.console.aws.amazon.com/codesuite/codebuild/projects/${CODEBUILD_PROJECT}/build/${BUILD_ID}/log"
echo "Console log:  $BUILD_URL"
echo ""

echo "Waiting for build to complete (polling every 30s)..."
while true; do
  BUILD_INFO=$(aws codebuild batch-get-builds \
    --ids "$BUILD_ID" \
    --region "$AWS_REGION" \
    --query 'builds[0].[buildStatus,currentPhase]' --output text)
  STATUS=$(echo "$BUILD_INFO" | cut -f1)
  PHASE=$(echo "$BUILD_INFO" | cut -f2)
  echo "  $(date +%H:%M:%S)  Status: $STATUS  Phase: $PHASE"
  case "$STATUS" in
    SUCCEEDED)
      echo ""
      echo "Build succeeded. All images pushed to $ECR_REGISTRY"
      echo "ECS services will pick up new :latest images on next deployment/restart."
      break ;;
    FAILED|FAULT|STOPPED|TIMED_OUT)
      echo ""
      echo "Build finished with status: $STATUS"
      echo "Check logs: $BUILD_URL"
      exit 1 ;;
  esac
  sleep 30
done

echo ""
echo "Done."
