#!/usr/bin/env bash
# Build the MCP Registration Lambda deployment zip.
#
# workshop-tools-stack.yaml references the zip via Code.S3Bucket/S3Key, so
# the zip must exist on disk before the staging pipeline syncs static/ to S3.
# AWS only auto-injects cfnresponse for inline ZipFile code, so we bundle it.
#
# Run before staging (stage-workshop-assets.sh calls this) or before any
# manual `aws lambda update-function-code` against a live deployment.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STATIC_DIR="$HERE/../static"

cd "$STATIC_DIR"
zip -qFS mcp_registration.zip mcp_registration.py cfnresponse.py
echo "Built: $STATIC_DIR/mcp_registration.zip ($(wc -c < mcp_registration.zip) bytes)"
