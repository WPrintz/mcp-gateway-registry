#!/bin/bash
# Build and push Grafana container to ECR

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO_NAME="mcp-gateway-grafana"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPO_URI="${ECR_REGISTRY}/${ECR_REPO_NAME}"

echo "Building Grafana container for MCP Gateway Workshop"
echo "  AWS Region: ${AWS_REGION}"
echo "  ECR Repo: ${ECR_REPO_URI}"

# Login to ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Create repository if it doesn't exist
echo "Creating ECR repository if it doesn't exist..."
aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" --region "${AWS_REGION}" 2>/dev/null || \
    aws ecr create-repository --repository-name "${ECR_REPO_NAME}" --region "${AWS_REGION}"

# Build the Docker image
echo "Building Docker image..."
cd "${SCRIPT_DIR}"
docker build -t "${ECR_REPO_NAME}" .

# Tag and push
echo "Tagging and pushing image..."
docker tag "${ECR_REPO_NAME}:latest" "${ECR_REPO_URI}:latest"
docker push "${ECR_REPO_URI}:latest"

echo ""
echo "Successfully built and pushed Grafana image to:"
echo "  ${ECR_REPO_URI}:latest"
echo ""
echo "Container URI saved to: ${SCRIPT_DIR}/.container_uri"
echo "${ECR_REPO_URI}:latest" > "${SCRIPT_DIR}/.container_uri"
