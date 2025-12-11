#!/bin/bash
# Export MCP Gateway container images from ECR to local tarballs
# Usage: ./export-ecr-images.sh [ACCOUNT_ID] [REGION] [OUTPUT_DIR]

set -e

# Configuration
ACCOUNT_ID=${1:-301774365272}
REGION=${2:-us-west-2}
OUTPUT_DIR=${3:-./workshop-images}
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.6")

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# All MCP Gateway images
IMAGES=(
  "mcp-gateway-currenttime"
  "mcp-gateway-realserverfaketools"
  "mcp-gateway-flight-booking-agent"
  "mcp-gateway-travel-assistant-agent"
  "mcp-gateway-auth-server"
  "mcp-gateway-keycloak"
  "mcp-gateway-mcpgw"
  "mcp-gateway-registry"
)

echo "=============================================="
echo "MCP Gateway ECR Image Export"
echo "=============================================="
echo "Account:    $ACCOUNT_ID"
echo "Region:     $REGION"
echo "Version:    $VERSION"
echo "Output:     $OUTPUT_DIR"
echo "=============================================="

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Login to ECR
echo ""
echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Export each image
for IMAGE in "${IMAGES[@]}"; do
  TARBALL="${OUTPUT_DIR}/${IMAGE}-${VERSION}.tar.gz"
  
  if [ -f "$TARBALL" ]; then
    echo ""
    echo "[$IMAGE] Already exists: $TARBALL (skipping)"
    continue
  fi
  
  echo ""
  echo "[$IMAGE] Pulling from ECR..."
  docker pull "${ECR_REGISTRY}/${IMAGE}:latest"
  
  echo "[$IMAGE] Exporting to tarball..."
  docker save "${ECR_REGISTRY}/${IMAGE}:latest" | gzip > "$TARBALL"
  
  SIZE=$(du -h "$TARBALL" | cut -f1)
  echo "[$IMAGE] Saved: $TARBALL ($SIZE)"
done

echo ""
echo "=============================================="
echo "Export complete!"
echo "=============================================="
echo ""
echo "Files created in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR"/*.tar.gz 2>/dev/null || echo "No files found"
echo ""
echo "To upload to S3 workshop bucket:"
echo "  aws s3 sync $OUTPUT_DIR s3://WORKSHOP_BUCKET/mcp-gateway/$VERSION/"
