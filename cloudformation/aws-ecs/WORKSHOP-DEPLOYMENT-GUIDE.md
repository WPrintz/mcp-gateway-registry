# MCP Gateway - Workshop Deployment Guide

This guide covers deploying the MCP Gateway infrastructure in AWS Workshop Studio accounts.

## Deployment Options

| Option | Description | Best For |
|--------|-------------|----------|
| **Single Stack** | One template, no S3 bucket needed | Workshop accounts, quick testing |
| **Nested Stacks** | 5 templates via S3 | Production, modular updates |

---

## Option A: Single Stack Deployment (Recommended for Workshops)

This is the simplest deployment method - just one CloudFormation template, no S3 bucket required.

### Step 1: Deploy the Single Stack

```bash
export AWS_REGION=us-west-2

aws cloudformation create-stack \
  --stack-name mcp-gateway \
  --template-body file://cloudformation/aws-ecs/templates/workshop-single-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --disable-rollback \
  --region ${AWS_REGION}
```

### Step 2: Monitor Deployment (~30-40 minutes)

```bash
# Check status
aws cloudformation describe-stacks \
  --stack-name mcp-gateway \
  --query 'Stacks[0].StackStatus' \
  --output text \
  --region ${AWS_REGION}

# Watch events
aws cloudformation describe-stack-events \
  --stack-name mcp-gateway \
  --query 'StackEvents[0:5].[Timestamp,ResourceStatus,LogicalResourceId]' \
  --output table \
  --region ${AWS_REGION}
```

### Step 3: Get Endpoints

```bash
aws cloudformation describe-stacks \
  --stack-name mcp-gateway \
  --query 'Stacks[0].Outputs' \
  --output table \
  --region ${AWS_REGION}
```

### Cleanup (Single Stack)

```bash
aws cloudformation delete-stack --stack-name mcp-gateway --region ${AWS_REGION}
```

---

## Option B: Nested Stack Deployment

Use this if you need modular updates or the single stack doesn't work in your environment.

## Prerequisites

- AWS Workshop Studio account with admin access
- AWS CLI configured with workshop credentials
- Access to the source code repository

## Step 1: Create S3 Bucket for Templates

```bash
# Set your AWS account ID (get from workshop console)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-west-2

# Create the S3 bucket for CloudFormation templates
aws s3 mb s3://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID} --region ${AWS_REGION}
```

## Step 2: Upload CloudFormation Templates

Upload all 5 templates to the S3 bucket:

```bash
# From the repository root directory
cd cloudformation/aws-ecs/templates

# Upload all templates
aws s3 cp network-stack.yaml s3://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID}/cloudformation/templates/
aws s3 cp data-stack.yaml s3://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID}/cloudformation/templates/
aws s3 cp compute-stack.yaml s3://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID}/cloudformation/templates/
aws s3 cp services-stack.yaml s3://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID}/cloudformation/templates/
aws s3 cp main-stack.yaml s3://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID}/cloudformation/templates/

# Verify uploads
aws s3 ls s3://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID}/cloudformation/templates/
```

## Step 3: Deploy the Main Stack

Deploy the nested stack with default parameters:

```bash
aws cloudformation create-stack \
  --stack-name mcp-gateway \
  --template-url https://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID}.s3.${AWS_REGION}.amazonaws.com/cloudformation/templates/main-stack.yaml \
  --parameters \
    ParameterKey=TemplateS3Bucket,ParameterValue=mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID} \
  --capabilities CAPABILITY_NAMED_IAM \
  --disable-rollback \
  --region ${AWS_REGION}
```

### Optional: Custom Passwords

To use custom passwords instead of defaults:

```bash
aws cloudformation create-stack \
  --stack-name mcp-gateway \
  --template-url https://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID}.s3.${AWS_REGION}.amazonaws.com/cloudformation/templates/main-stack.yaml \
  --parameters \
    ParameterKey=TemplateS3Bucket,ParameterValue=mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID} \
    ParameterKey=KeycloakDatabasePassword,ParameterValue=YourSecureDbPassword123! \
    ParameterKey=KeycloakAdminPassword,ParameterValue=YourSecureAdminPassword123! \
  --capabilities CAPABILITY_NAMED_IAM \
  --disable-rollback \
  --region ${AWS_REGION}
```

## Step 4: Monitor Deployment

The deployment takes approximately 25-35 minutes. Monitor progress:

```bash
# Watch stack events
aws cloudformation describe-stack-events \
  --stack-name mcp-gateway \
  --query 'StackEvents[0:10].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
  --output table \
  --region ${AWS_REGION}

# Check overall status
aws cloudformation describe-stacks \
  --stack-name mcp-gateway \
  --query 'Stacks[0].StackStatus' \
  --output text \
  --region ${AWS_REGION}
```

### Expected Nested Stack Creation Order

1. `NetworkStack` (~3 min) - VPC, subnets, NAT gateways
2. `DataStack` (~15 min) - Aurora cluster, EFS, secrets
3. `ComputeStack` (~10 min) - ECS clusters, ALBs, CodeBuild (builds container images)
4. `ServicesStack` (~5 min) - ECS services

## Step 5: Get Service Endpoints

Once deployment completes:

```bash
# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name mcp-gateway \
  --query 'Stacks[0].Outputs' \
  --output table \
  --region ${AWS_REGION}
```

Key outputs:
- `KeycloakUrl` - Keycloak HTTPS URL (via CloudFront)
- `RegistryUrl` - Registry URL
- `MainAlbDnsName` - Main ALB DNS name

## Step 6: Verify Services

```bash
# Test Keycloak (should return HTTP 200)
KEYCLOAK_URL=$(aws cloudformation describe-stacks \
  --stack-name mcp-gateway \
  --query 'Stacks[0].Outputs[?OutputKey==`KeycloakUrl`].OutputValue' \
  --output text \
  --region ${AWS_REGION})

curl -s -o /dev/null -w "Keycloak Status: %{http_code}\n" "${KEYCLOAK_URL}/realms/master"

# Verify HTTPS URLs in OpenID config
curl -s "${KEYCLOAK_URL}/realms/master/.well-known/openid-configuration" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('issuer:', d.get('issuer'))"
```

## Known Issues

### Docker Hub Rate Limiting

The container images use `public.ecr.aws/docker/library/python:3.12-slim` as the base image instead of Docker Hub's `python:3.12-slim`. This avoids Docker Hub's unauthenticated pull rate limits (429 Too Many Requests) which can cause CodeBuild failures in workshop environments.

If you see rate limit errors during CodeBuild, the Dockerfiles have already been updated to use ECR Public Gallery mirrors.

### Keycloak ALB Listener Deletion

In some AWS accounts, the Keycloak ALB HTTP listener may be automatically deleted by AWS internal security automation. If you see 502 errors from CloudFront:

```bash
# Get ALB and Target Group ARNs
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names mcp-gateway-keycloak-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text --region ${AWS_REGION})

TG_ARN=$(aws elbv2 describe-target-groups \
  --names mcp-gateway-keycloak-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text --region ${AWS_REGION})

# Check if listener exists
aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --region ${AWS_REGION}

# If no listeners, recreate:
aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
  --region ${AWS_REGION}
```

## Cleanup

Delete the stack when done (takes ~15 minutes):

```bash
# Delete the main stack (deletes all nested stacks)
aws cloudformation delete-stack \
  --stack-name mcp-gateway \
  --region ${AWS_REGION}

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name mcp-gateway \
  --region ${AWS_REGION}

# Delete the S3 bucket
aws s3 rb s3://mcp-gateway-cfn-templates-${AWS_ACCOUNT_ID} --force
```

### Manual Cleanup (if stack deletion fails)

If stack deletion fails due to non-empty ECR repositories:

```bash
# List ECR repositories
aws ecr describe-repositories \
  --query 'repositories[?starts_with(repositoryName, `mcp-gateway`)].repositoryName' \
  --output text --region ${AWS_REGION}

# Delete each repository (force deletes images)
for repo in mcp-gateway-registry mcp-gateway-auth-server mcp-gateway-keycloak \
            mcp-gateway-currenttime mcp-gateway-mcpgw mcp-gateway-realserverfaketools \
            mcp-gateway-flight-booking-agent mcp-gateway-travel-assistant-agent; do
  aws ecr delete-repository --repository-name $repo --force --region ${AWS_REGION} 2>/dev/null || true
done

# Retry stack deletion
aws cloudformation delete-stack --stack-name mcp-gateway --region ${AWS_REGION}
```

## Architecture Summary

| Component | Location | Notes |
|-----------|----------|-------|
| ALBs | Public subnets | Internet-facing |
| ECS Tasks | Private subnets | No public IPs |
| Aurora | Private subnets | Encrypted |
| EFS | Private subnets | Encrypted |
| Keycloak HTTPS | CloudFront | Default *.cloudfront.net cert |

## Files Required

### Single Stack (Option A)
```
cloudformation/aws-ecs/templates/
└── workshop-single-stack.yaml    # Everything in one file (~3000 lines)
```

### Nested Stacks (Option B)
```
cloudformation/aws-ecs/templates/
├── main-stack.yaml        # Parent orchestration (deploy this)
├── network-stack.yaml     # VPC, subnets, security groups
├── data-stack.yaml        # EFS, Aurora, secrets
├── compute-stack.yaml     # ECS clusters, ALBs, ECR
└── services-stack.yaml    # ECS services
```

## Default Credentials

| Credential | Default Value | Parameter |
|------------|---------------|-----------|
| Keycloak Admin | admin | (hardcoded) |
| Keycloak Admin Password | AdminPassword2025! | KeycloakAdminPassword |
| Database Username | keycloak | KeycloakDatabaseUsername |
| Database Password | McpGateway2025! | KeycloakDatabasePassword |

**Note**: Change these for production use!
