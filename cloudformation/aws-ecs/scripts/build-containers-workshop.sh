#!/usr/bin/env bash
# Build container images from source via CodeBuild in the workshop account
# and push directly to workshop ECR. This is the "fast path" that bypasses
# the S3 tarball export pipeline.
#
# Uses the existing mcp-gateway-container-build CodeBuild project with
# --source-type-override GITHUB to build from source, and an inline
# --buildspec-override to build and push selected images.
#
# Requires workshop account credentials in the environment (source ws-creds.env).
# Does NOT use --profile.
#
# Usage:
#   ./cloudformation/aws-ecs/scripts/build-containers-workshop.sh                # build all 10 images
#   ./cloudformation/aws-ecs/scripts/build-containers-workshop.sh -i "mcp-gateway-realserverfaketools"
#   ./cloudformation/aws-ecs/scripts/build-containers-workshop.sh --branch main -i "mcp-gateway-registry mcp-gateway-auth-server"
#
# Environment variables (override defaults):
#   AWS_REGION           - region (default: us-west-2)
#   CODEBUILD_PROJECT    - CodeBuild project name (default: mcp-gateway-container-build)
#   IMAGE_TAG            - image tag (default: latest)
#   GITHUB_REPO_URL      - GitHub repo URL (default: https://github.com/WPrintz/mcp-gateway-registry.git)

set -euo pipefail

ALL_IMAGES=(
  mcp-gateway-registry
  mcp-gateway-auth-server
  mcp-gateway-currenttime
  mcp-gateway-mcpgw
  mcp-gateway-realserverfaketools
  mcp-gateway-flight-booking-agent
  mcp-gateway-travel-assistant-agent
  mcp-gateway-keycloak
  mcp-gateway-grafana
  mcp-gateway-metrics-service
)

AWS_REGION="${AWS_REGION:-us-west-2}"
CODEBUILD_PROJECT="${CODEBUILD_PROJECT:-mcp-gateway-container-build}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/WPrintz/mcp-gateway-registry.git}"
BRANCH=""
IMAGES=()

_usage() {
  sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$0"
  echo ""
  echo "Options:"
  echo "  -i, --images IMAGES   Space-separated list of images to build (default: all)"
  echo "  -b, --branch BRANCH   Git branch to build from (default: current branch)"
  echo "  -t, --tag TAG         Image tag (default: latest)"
  echo "  -h, --help            Show this help"
  echo ""
  echo "Available images:"
  printf "  %s\n" "${ALL_IMAGES[@]}"
}


_get_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main"
}


_validate_images() {
  local valid
  for img in "$@"; do
    valid=false
    for known in "${ALL_IMAGES[@]}"; do
      if [ "$img" = "$known" ]; then
        valid=true
        break
      fi
    done
    if [ "$valid" = false ]; then
      echo "ERROR: Unknown image '$img'"
      echo "Available images:"
      printf "  %s\n" "${ALL_IMAGES[@]}"
      exit 1
    fi
  done
}


_generate_build_commands() {
  local images=("$@")
  local cmds=""

  for img in "${images[@]}"; do
    case "$img" in
      mcp-gateway-registry)
        cmds+="build_and_push mcp-gateway-registry docker/Dockerfile.registry-cpu . &"$'\n' ;;
      mcp-gateway-auth-server)
        cmds+="build_and_push mcp-gateway-auth-server docker/Dockerfile.auth . &"$'\n' ;;
      mcp-gateway-currenttime)
        cmds+="build_and_push mcp-gateway-currenttime docker/Dockerfile.mcp-server servers/currenttime &"$'\n' ;;
      mcp-gateway-mcpgw)
        cmds+="(docker build -t \$ECR_REGISTRY/mcp-gateway-mcpgw:\$IMAGE_TAG --build-arg SERVER_DIR=servers/mcpgw --build-arg BUILD_VERSION=\$IMAGE_TAG -f docker/Dockerfile.mcp-server-cpu . && docker tag \$ECR_REGISTRY/mcp-gateway-mcpgw:\$IMAGE_TAG \$ECR_REGISTRY/mcp-gateway-mcpgw:latest && docker push \$ECR_REGISTRY/mcp-gateway-mcpgw:\$IMAGE_TAG && docker push \$ECR_REGISTRY/mcp-gateway-mcpgw:latest && echo 'Completed: mcp-gateway-mcpgw' || { echo 'FAILED: mcp-gateway-mcpgw'; exit 1; }) &"$'\n' ;;
      mcp-gateway-realserverfaketools)
        cmds+="build_and_push mcp-gateway-realserverfaketools docker/Dockerfile.mcp-server servers/realserverfaketools &"$'\n' ;;
      mcp-gateway-flight-booking-agent)
        cmds+="build_and_push mcp-gateway-flight-booking-agent agents/a2a/src/flight-booking-agent/Dockerfile agents/a2a/src/flight-booking-agent &"$'\n' ;;
      mcp-gateway-travel-assistant-agent)
        cmds+="build_and_push mcp-gateway-travel-assistant-agent agents/a2a/src/travel-assistant-agent/Dockerfile agents/a2a/src/travel-assistant-agent &"$'\n' ;;
      mcp-gateway-keycloak)
        cmds+="build_and_push mcp-gateway-keycloak docker/keycloak/Dockerfile docker/keycloak &"$'\n' ;;
      mcp-gateway-grafana)
        cmds+="build_and_push mcp-gateway-grafana cloudformation/aws-ecs/grafana/Dockerfile cloudformation/aws-ecs/grafana &"$'\n' ;;
      mcp-gateway-metrics-service)
        cmds+="build_and_push mcp-gateway-metrics-service metrics-service/Dockerfile metrics-service &"$'\n' ;;
    esac
  done

  echo "$cmds"
}


_generate_buildspec() {
  local images=("$@")
  local build_commands
  build_commands=$(_generate_build_commands "${images[@]}")

  # Check if A2A agents are in the image list (need dependency setup)
  local needs_a2a=false
  for img in "${images[@]}"; do
    if [ "$img" = "mcp-gateway-flight-booking-agent" ] || [ "$img" = "mcp-gateway-travel-assistant-agent" ]; then
      needs_a2a=true
      break
    fi
  done

  local a2a_setup=""
  if [ "$needs_a2a" = true ]; then
    a2a_setup='      - mkdir -p agents/a2a/src/flight-booking-agent/.tmp agents/a2a/src/travel-assistant-agent/.tmp
      - cp agents/a2a/pyproject.toml agents/a2a/uv.lock agents/a2a/src/flight-booking-agent/.tmp/
      - cp agents/a2a/pyproject.toml agents/a2a/uv.lock agents/a2a/src/travel-assistant-agent/.tmp/'
  fi

  cat <<BUILDSPEC_EOF
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin \$ECR_REGISTRY
      - echo Pre-pulling base images for layer caching...
      - docker pull public.ecr.aws/docker/library/python:3.12-slim
      - docker tag public.ecr.aws/docker/library/python:3.12-slim python:3.12-slim
      - docker pull quay.io/keycloak/keycloak:23.0
      - docker pull grafana/grafana:12.3.1
${a2a_setup:+$a2a_setup
}  build:
    commands:
      - echo Building container images in parallel...
      - |
        echo "Using image tag: \$IMAGE_TAG"

        build_and_push() {
          local name=\$1
          local dockerfile=\$2
          local context=\$3
          echo "Starting build: \$name"
          if docker build -t \$ECR_REGISTRY/\$name:\$IMAGE_TAG --build-arg BUILD_VERSION=\$IMAGE_TAG -f \$dockerfile \$context && \\
             docker tag \$ECR_REGISTRY/\$name:\$IMAGE_TAG \$ECR_REGISTRY/\$name:latest && \\
             docker push \$ECR_REGISTRY/\$name:\$IMAGE_TAG && \\
             docker push \$ECR_REGISTRY/\$name:latest; then
            echo "Completed: \$name"
          else
            echo "FAILED: \$name"
            return 1
          fi
        }

${build_commands}
        FAILED=0
        for job in \$(jobs -p); do
          wait \$job || FAILED=\$((FAILED+1))
        done

        if [ \$FAILED -gt 0 ]; then
          echo "\$FAILED build(s) failed"
          exit 1
        fi
        echo "All builds completed successfully"
  post_build:
    commands:
      - echo Build completed on \$(date)
BUILDSPEC_EOF
}


# --- Parse arguments ---
while [ $# -gt 0 ]; do
  case "$1" in
    -i|--images)
      shift
      read -ra IMAGES <<< "$1"
      ;;
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

# Default to all images if none specified
if [ ${#IMAGES[@]} -eq 0 ]; then
  IMAGES=("${ALL_IMAGES[@]}")
fi

# Default to current branch
if [ -z "$BRANCH" ]; then
  BRANCH=$(_get_current_branch)
fi

# Validate images
_validate_images "${IMAGES[@]}"

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
echo "  Images:     ${IMAGES[*]}"
echo ""

# Generate inline buildspec
BUILDSPEC=$(_generate_buildspec "${IMAGES[@]}")

# Start CodeBuild with source override pointing to GitHub
BUILD_ID=$(aws codebuild start-build \
  --project-name "$CODEBUILD_PROJECT" \
  --region "$AWS_REGION" \
  --source-type-override GITHUB \
  --source-location-override "$GITHUB_REPO_URL" \
  --source-version "$BRANCH" \
  --buildspec-override "$BUILDSPEC" \
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
      echo "Build succeeded. Images pushed to $ECR_REGISTRY"
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
