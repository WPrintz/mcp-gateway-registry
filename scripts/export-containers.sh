#!/usr/bin/env bash
# Build all container images via CodeBuild in your personal AWS account,
# export as split gzipped tarballs, and upload to S3.
#
# Uses your existing CodeBuild project with --buildspec-override to run
# the export buildspec (scripts/codebuild/buildspec-export.yaml) and
# --source-version to select the branch. No dedicated project needed.
#
# The build runs in your personal AWS account (uses --profile), while
# --download-only fetches from Workshop Studio S3 using environment creds.
#
# Usage:
#   ./scripts/export-containers.sh                    # trigger build, wait
#   ./scripts/export-containers.sh --download         # trigger build, wait, download
#   ./scripts/export-containers.sh --download-only    # skip build, download from S3
#
# Environment variables (override defaults):
#   AWS_PROFILE_BUILD    - AWS CLI profile for CodeBuild (default: printw-Admin)
#   CODEBUILD_PROJECT    - CodeBuild project name (default: mcp-gateway-export-containers)
#   SOURCE_VERSION       - git branch to build from (default: cloudformation/workshop-v1.0.15)
#   IMAGE_TAG            - image tag for docker save (default: v1.0.15)
#   S3_DEST_BUCKET       - S3 bucket for tarball upload (default: mcp-gateway-codebuild-cache-<account-id>)
#   S3_DEST_PREFIX       - S3 key prefix for tarballs (default: container-exports)
#   S3_DEST_DATE         - Date stamp for versioned subfolder (default: today, YYYY-MM-DD)
#   WS_S3_BUCKET         - Workshop Studio S3 bucket for --download-only (default: ws-assets-us-east-1)
#   WS_S3_PREFIX         - Workshop Studio S3 prefix (default: <update-with-wss-guid>/containers)
#   AWS_REGION           - region (default: us-east-1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AWS_PROFILE_BUILD="${AWS_PROFILE_BUILD:-printw-Admin}"
CODEBUILD_PROJECT="${CODEBUILD_PROJECT:-mcp-gateway-export-containers}"
SOURCE_VERSION="${SOURCE_VERSION:-cloudformation/workshop-v1.0.15}"
IMAGE_TAG="${IMAGE_TAG:-v1.0.15}"
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE_BUILD" --query 'Account' --output text 2>/dev/null || echo "UNKNOWN")
S3_DEST_BUCKET="${S3_DEST_BUCKET:-mcp-gateway-codebuild-cache-${ACCOUNT_ID}}"
S3_DEST_PREFIX="${S3_DEST_PREFIX:-container-exports}"
S3_DEST_DATE="${S3_DEST_DATE:-$(date +%Y-%m-%d)}"
S3_FULL_PREFIX="${S3_DEST_PREFIX}/${IMAGE_TAG}-${S3_DEST_DATE}"
WS_S3_BUCKET="${WS_S3_BUCKET:-ws-assets-us-east-1}"
WS_S3_PREFIX="${WS_S3_PREFIX:-0c3265a6-1a4a-467b-ae56-e4d019184b0e/containers}"
AWS_REGION="${AWS_REGION:-us-east-1}"

DOWNLOAD=false
SKIP_BUILD=false

for arg in "$@"; do
  case "$arg" in
    --download) DOWNLOAD=true ;;
    --download-only) DOWNLOAD=true; SKIP_BUILD=true ;;
    -h|--help)
      sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$0"
      exit 0 ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

CONTAINERS_DIR="$REPO_ROOT/cloudformation/aws-ecs/containers"

if [ "$SKIP_BUILD" = false ]; then
  echo "=== Export Container Build ==="
  echo "  Project:    $CODEBUILD_PROJECT"
  echo "  Profile:    $AWS_PROFILE_BUILD"
  echo "  Branch:     $SOURCE_VERSION"
  echo "  Image tag:  $IMAGE_TAG"
  echo "  S3 dest:    s3://$S3_DEST_BUCKET/$S3_FULL_PREFIX/"
  echo ""

  BUILD_ID=$(aws codebuild start-build \
    --project-name "$CODEBUILD_PROJECT" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE_BUILD" \
    --source-version "$SOURCE_VERSION" \
    --buildspec-override scripts/codebuild/buildspec-export.yaml \
    --environment-variables-override \
      "[{\"name\":\"IMAGE_TAG\",\"value\":\"$IMAGE_TAG\",\"type\":\"PLAINTEXT\"},
        {\"name\":\"S3_DEST_BUCKET\",\"value\":\"$S3_DEST_BUCKET\",\"type\":\"PLAINTEXT\"},
        {\"name\":\"S3_DEST_PREFIX\",\"value\":\"$S3_DEST_PREFIX\",\"type\":\"PLAINTEXT\"},
        {\"name\":\"S3_DEST_DATE\",\"value\":\"$S3_DEST_DATE\",\"type\":\"PLAINTEXT\"}]" \
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
      --profile "$AWS_PROFILE_BUILD" \
      --query 'builds[0].[buildStatus,currentPhase]' --output text)
    STATUS=$(echo "$BUILD_INFO" | cut -f1)
    PHASE=$(echo "$BUILD_INFO" | cut -f2)
    echo "  $(date +%H:%M:%S)  Status: $STATUS  Phase: $PHASE"
    case "$STATUS" in
      SUCCEEDED)
        echo ""
        echo "Build succeeded."
        echo "Tarballs at: s3://$S3_DEST_BUCKET/$S3_FULL_PREFIX/"
        echo ""
        aws s3 ls "s3://$S3_DEST_BUCKET/$S3_FULL_PREFIX/" \
          --profile "$AWS_PROFILE_BUILD" --region "$AWS_REGION" \
          --human-readable --summarize
        break ;;
      FAILED|FAULT|STOPPED|TIMED_OUT)
        echo ""
        echo "Build finished with status: $STATUS"
        echo "Check logs: $BUILD_URL"
        exit 1 ;;
    esac
    sleep 30
  done

  if [ "$DOWNLOAD" = true ]; then
    echo ""
    echo "Downloading tarballs from build output to $CONTAINERS_DIR ..."
    mkdir -p "$CONTAINERS_DIR"
    aws s3 sync "s3://$S3_DEST_BUCKET/$S3_FULL_PREFIX/" "$CONTAINERS_DIR/" \
      --profile "$AWS_PROFILE_BUILD" --region "$AWS_REGION"
    echo "Download complete:"
    ls -lh "$CONTAINERS_DIR/"
  fi
else
  # --download-only: fetch from Workshop Studio S3 using environment creds
  echo "Downloading tarballs from Workshop Studio S3 to $CONTAINERS_DIR ..."
  echo "  Source: s3://$WS_S3_BUCKET/$WS_S3_PREFIX/"
  echo "  (Using environment credentials, not --profile)"
  mkdir -p "$CONTAINERS_DIR"
  aws s3 sync "s3://$WS_S3_BUCKET/$WS_S3_PREFIX/" "$CONTAINERS_DIR/" --region us-east-1
  echo "Download complete:"
  ls -lh "$CONTAINERS_DIR/"
fi

echo ""
echo "Done."
