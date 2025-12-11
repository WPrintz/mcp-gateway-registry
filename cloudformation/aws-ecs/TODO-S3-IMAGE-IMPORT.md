# TODO: S3 Container Image Import for Workshop

## Overview

Replace GitHub source builds with pre-built container image tarballs from S3 to:
- Reduce deployment time from ~15 min to ~3 min
- Eliminate Docker Hub rate limiting issues
- Ensure reproducible workshop deployments
- Remove dependency on GitHub availability

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Pre-build      │────▶│   Workshop S3   │────▶│  Participant's  │
│  (one-time)     │     │   Bucket        │     │  ECR Repos      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
   docker save            mcp-gateway/           docker load
   → .tar.gz              v1.0.6/*.tar.gz        docker push
```

---

## Implementation Tasks

### Phase 1: CloudFormation Parameter Changes

#### 1.1 Add parameters to `main-stack.yaml`

After the `KeycloakLogLevel` parameter (~line 210), add:

```yaml
  # Pre-built Container Images (S3 Import)
  ContainerImagesBucket:
    Type: String
    Default: ''
    Description: S3 bucket containing pre-built container image tarballs (empty = build from source)

  ContainerImagesPrefix:
    Type: String
    Default: ''
    Description: S3 prefix for container image tarballs (e.g., mcp-gateway/v1.0.6/)
```

#### 1.2 Add parameters to `compute-stack.yaml`

After the `GitHubBranch` parameter (~line 95), add the same two parameters.

#### 1.3 Pass parameters from main-stack to compute-stack

In `main-stack.yaml`, update the ComputeStack resource (~line 285):

```yaml
  ComputeStack:
    Type: AWS::CloudFormation::Stack
    DependsOn: DataStack
    Properties:
      TemplateURL: !Sub 'https://${TemplateS3Bucket}.s3.${AWS::Region}.amazonaws.com/${TemplateS3Prefix}compute-stack.yaml'
      Parameters:
        EnvironmentName: !Ref EnvironmentName
        BaseDomain: !Ref BaseDomain
        HostedZoneId: !Ref HostedZoneId
        UseRegionalDomains: !Ref UseRegionalDomains
        ContainerImagesBucket: !Ref ContainerImagesBucket      # ADD
        ContainerImagesPrefix: !Ref ContainerImagesPrefix      # ADD
```

---

### Phase 2: CodeBuild Environment Variables

#### 2.1 Add environment variables to ContainerBuildProject

In `compute-stack.yaml`, find the `ContainerBuildProject` resource (~line 560) and add to `EnvironmentVariables`:

```yaml
        EnvironmentVariables:
          - Name: AWS_ACCOUNT_ID
            Value: !Ref AWS::AccountId
          - Name: AWS_REGION
            Value: !Ref AWS::Region
          - Name: ECR_REGISTRY
            Value: !Sub ${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com
          # ADD THESE:
          - Name: CONTAINER_IMAGES_BUCKET
            Value: !Ref ContainerImagesBucket
          - Name: CONTAINER_IMAGES_PREFIX
            Value: !Ref ContainerImagesPrefix
```

---

### Phase 3: Update BuildSpec

#### 3.1 Modify inline buildspec in `compute-stack.yaml`

Replace the current buildspec (~line 583) with logic that:
1. Checks if `CONTAINER_IMAGES_BUCKET` is set
2. If set: download tarballs from S3, load into Docker, push to ECR
3. If not set: use existing build-from-source logic

```yaml
BuildSpec: |
  version: 0.2
  phases:
    pre_build:
      commands:
        - echo Logging in to Amazon ECR...
        - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
        
        # Determine build mode
        - |
          if [ -n "$CONTAINER_IMAGES_BUCKET" ] && [ -n "$CONTAINER_IMAGES_PREFIX" ]; then
            echo "BUILD_MODE=import" >> /tmp/build_mode
            echo "Using pre-built images from s3://$CONTAINER_IMAGES_BUCKET/$CONTAINER_IMAGES_PREFIX"
          else
            echo "BUILD_MODE=source" >> /tmp/build_mode
            echo "Building from source code"
            # Pre-pull base images for layer caching
            docker pull public.ecr.aws/docker/library/python:3.12-slim
            docker pull quay.io/keycloak/keycloak:23.0
          fi
        - source /tmp/build_mode
        
    build:
      commands:
        - source /tmp/build_mode
        - |
          if [ "$BUILD_MODE" = "import" ]; then
            # Import from S3
            IMAGES="mcp-gateway-registry mcp-gateway-auth-server mcp-gateway-currenttime mcp-gateway-mcpgw mcp-gateway-realserverfaketools mcp-gateway-flight-booking-agent mcp-gateway-travel-assistant-agent mcp-gateway-keycloak"
            
            for IMAGE in $IMAGES; do
              echo "Importing $IMAGE..."
              aws s3 cp s3://$CONTAINER_IMAGES_BUCKET/${CONTAINER_IMAGES_PREFIX}${IMAGE}.tar.gz - | docker load
              docker tag ${IMAGE}:latest $ECR_REGISTRY/${IMAGE}:latest
              docker push $ECR_REGISTRY/${IMAGE}:latest &
            done
            
            # Wait for all pushes
            wait
            echo "All images imported and pushed"
          else
            # Build from source (existing logic)
            # ... keep existing parallel build logic ...
          fi
          
    post_build:
      commands:
        - echo Build completed on `date`
```

---

### Phase 4: IAM Permissions

#### 4.1 Add S3 read permissions to CodeBuild role

In `compute-stack.yaml`, find `CodeBuildServiceRole` (~line 500) and add:

```yaml
              - Effect: Allow
                Action:
                  - s3:GetObject
                Resource:
                  - !Sub 'arn:aws:s3:::${ContainerImagesBucket}/*'
                Condition:
                  StringNotEquals:
                    aws:ResourceAccount: ''  # Only if bucket is specified
```

Or use a condition to only add this when bucket is provided.

---

### Phase 5: Pre-build Container Images

#### 5.1 Create build script for generating tarballs

Create `scripts/build-workshop-images.sh`:

```bash
#!/bin/bash
# Build and export container images for workshop S3 bucket

VERSION=${1:-v1.0.6}
OUTPUT_DIR=${2:-./workshop-images}

mkdir -p $OUTPUT_DIR

IMAGES=(
  "mcp-gateway-registry:docker/Dockerfile.registry:."
  "mcp-gateway-auth-server:docker/Dockerfile.auth:."
  "mcp-gateway-currenttime:docker/Dockerfile.mcp-server:servers/currenttime"
  "mcp-gateway-mcpgw:docker/Dockerfile.mcp-server:servers/mcpgw"
  "mcp-gateway-realserverfaketools:docker/Dockerfile.mcp-server:servers/realserverfaketools"
  "mcp-gateway-flight-booking-agent:agents/a2a/src/flight-booking-agent/Dockerfile:agents/a2a/src/flight-booking-agent"
  "mcp-gateway-travel-assistant-agent:agents/a2a/src/travel-assistant-agent/Dockerfile:agents/a2a/src/travel-assistant-agent"
  "mcp-gateway-keycloak:docker/keycloak/Dockerfile:docker/keycloak"
)

for entry in "${IMAGES[@]}"; do
  IFS=':' read -r name dockerfile context <<< "$entry"
  echo "Building $name..."
  docker build -t ${name}:${VERSION} -f $dockerfile $context
  echo "Exporting $name..."
  docker save ${name}:${VERSION} | gzip > ${OUTPUT_DIR}/${name}.tar.gz
done

echo "Done! Upload to S3:"
echo "aws s3 sync $OUTPUT_DIR s3://WORKSHOP_BUCKET/mcp-gateway/${VERSION}/"
```

#### 5.2 Upload to workshop S3 bucket

```bash
aws s3 sync ./workshop-images s3://WORKSHOP_BUCKET/mcp-gateway/v1.0.6/
```

---

## Testing

### Test 1: Build from source (default)

Deploy with empty bucket parameters - should use existing GitHub build.

### Test 2: Import from S3

Deploy with:
```
ContainerImagesBucket: workshop-assets-bucket
ContainerImagesPrefix: mcp-gateway/v1.0.6/
```

Verify:
- Build completes in ~3 minutes
- All 8 images appear in ECR
- Services start successfully

---

## Files to Modify

| File | Changes |
|------|---------|
| `main-stack.yaml` | Add 2 parameters, pass to ComputeStack |
| `compute-stack.yaml` | Add 2 parameters, env vars, update buildspec, IAM |
| `scripts/build-workshop-images.sh` | New file for pre-building images |

---

## Rollback

If S3 import fails, participants can redeploy with empty `ContainerImagesBucket` to fall back to source builds.
