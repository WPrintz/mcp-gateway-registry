# MCP Gateway Registry - AWS CloudFormation Deployment

Production-grade infrastructure for the MCP Gateway Registry using AWS CloudFormation with ECS Fargate, Aurora Serverless, and Keycloak authentication.

[![Infrastructure](https://img.shields.io/badge/infrastructure-cloudformation-orange)](https://aws.amazon.com/cloudformation/)
[![AWS ECS](https://img.shields.io/badge/compute-ECS%20Fargate-orange)](https://aws.amazon.com/ecs/)
[![Database](https://img.shields.io/badge/database-Aurora%20Serverless%20v2-blue)](https://aws.amazon.com/rds/aurora/)

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Post-Deployment](#post-deployment)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)

## Architecture

The infrastructure deploys the following components using nested CloudFormation stacks:

```
┌─────────────────────────────────────────────────────────────────┐
│                     main-stack.yaml                              │
│                   (Parent/Root Stack)                            │
├─────────────────────────────────────────────────────────────────┤
│  Nested Stacks:                                                  │
│    ├── vpc-stack.yaml          (VPC, Subnets, NAT Gateways)     │
│    ├── security-groups-stack   (All Security Groups)            │
│    ├── efs-stack.yaml          (EFS + Access Points)            │
│    ├── database-stack.yaml     (Aurora Serverless + RDS Proxy)  │
│    ├── secrets-stack.yaml      (Secrets Manager + SSM)          │
│    ├── iam-stack.yaml          (IAM Roles + Policies)           │
│    ├── ecr-stack.yaml          (ECR Repositories)               │
│    ├── ecs-cluster-stack.yaml  (ECS Clusters)                   │
│    ├── alb-stack.yaml          (Load Balancers)                 │
│    ├── dns-stack.yaml          (Route53 + ACM Certificates)     │
│    ├── ecs-services-stack.yaml (Task Definitions + Services)    │
│    └── autoscaling-stack.yaml  (Auto Scaling Policies)          │
└─────────────────────────────────────────────────────────────────┘
```

### Services Deployed

| Service | Port | Description |
|---------|------|-------------|
| Registry | 7860, 80, 443 | Main MCP Gateway Registry |
| Auth Server | 8888 | OAuth2/OIDC Authentication |
| Keycloak | 8080 | Identity Management |
| CurrentTime MCP | 8000 | Example MCP Server |
| MCPGW MCP | 8003 | MCP Gateway Server |
| RealServerFakeTools | 8002 | Example MCP Server |
| Flight Booking Agent | 9000 | A2A Agent |
| Travel Assistant Agent | 9001 | A2A Agent |

## Prerequisites

### Required Tools

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| AWS CLI | >= 2.0 | [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| cfn-lint | Latest | `pip install cfn-lint` |
| Docker | >= 20.10 | [docs.docker.com/engine/install](https://docs.docker.com/engine/install/) |

### AWS Account Setup

You need an AWS account with permissions to create:
- VPC, Subnets, NAT Gateways, Internet Gateways
- ECS Clusters, Task Definitions, Services
- RDS Aurora Clusters, RDS Proxy
- EFS File Systems
- Application Load Balancers
- Route53 Records, ACM Certificates
- IAM Roles and Policies
- Secrets Manager Secrets, SSM Parameters
- CloudWatch Log Groups
- ECR Repositories

### Domain Configuration

You need a domain with a Route53 hosted zone. The infrastructure creates:
- `registry.{region}.{base_domain}` - Main registry endpoint
- `kc.{region}.{base_domain}` - Keycloak endpoint

## Quick Start

```bash
# 1. Validate templates
./scripts/validate.sh

# 2. Configure parameters
cp parameters.json.example parameters.json
# Edit parameters.json with your values

# 3. Deploy (two-stage for certificate validation)
./scripts/deploy.sh

# 4. Wait for stack completion (~20-30 minutes)
aws cloudformation wait stack-create-complete --stack-name mcp-gateway
```

## Configuration

### Required Parameters

Edit `parameters.json` with your values:

```json
{
  "Parameters": {
    "BaseDomain": "mycorp.click",
    "HostedZoneId": "Z1234567890ABC",
    "RegistryImageUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/mcp-gateway-registry:latest",
    "AuthServerImageUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/mcp-gateway-auth-server:latest",
    "KeycloakAdminPassword": "YourSecurePassword123!",
    "KeycloakDatabasePassword": "YourDBPassword456!",
    "IngressCidrBlocks": "0.0.0.0/0"
  }
}
```

### Parameter Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `VpcCidr` | VPC CIDR block | `10.0.0.0/16` |
| `BaseDomain` | Base domain for regional URLs | Required |
| `HostedZoneId` | Route53 Hosted Zone ID | Required |
| `UseRegionalDomains` | Use region-based domain names | `true` |
| `IngressCidrBlocks` | Allowed CIDR blocks for ALB | `0.0.0.0/0` |
| `KeycloakAdminPassword` | Keycloak admin password | Required |
| `KeycloakDatabasePassword` | Aurora database password | Required |
| `EnableMonitoring` | Enable CloudWatch monitoring | `true` |

## Deployment

### Two-Stage Deployment

Due to ACM certificate DNS validation dependencies, first-time deployments require two stages:

**Stage 1: Deploy certificates**
```bash
aws cloudformation deploy \
  --template-file templates/dns-stack.yaml \
  --stack-name mcp-gateway-dns \
  --parameter-overrides file://parameters.json \
  --capabilities CAPABILITY_IAM

# Wait for certificate validation (5-10 minutes)
```

**Stage 2: Deploy full infrastructure**
```bash
aws cloudformation deploy \
  --template-file main-stack.yaml \
  --stack-name mcp-gateway \
  --parameter-overrides file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

### Using the Deploy Script

```bash
# Full deployment
./scripts/deploy.sh

# Delete stack
./scripts/delete.sh
```

## Post-Deployment

### Verify Deployment

```bash
# Get stack outputs
aws cloudformation describe-stacks \
  --stack-name mcp-gateway \
  --query 'Stacks[0].Outputs'

# Check ECS services
aws ecs list-services --cluster mcp-gateway-ecs-cluster
```

### Access URLs

After deployment, access your services at:
- Registry: `https://registry.{region}.{base_domain}`
- Keycloak Admin: `https://kc.{region}.{base_domain}/admin`

## Troubleshooting

### Stack Creation Failed

```bash
# View stack events
aws cloudformation describe-stack-events \
  --stack-name mcp-gateway \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

### Certificate Validation Stuck

Ensure your Route53 hosted zone is properly configured and DNS is propagating:
```bash
dig NS mycorp.click +short
```

### ECS Tasks Not Starting

Check CloudWatch logs:
```bash
aws logs tail /ecs/mcp-gateway-registry --follow
```

## Cost Optimization

Estimated monthly costs (us-east-1):
- ECS Fargate: ~$50-100 (depends on task count)
- Aurora Serverless: ~$30-50 (0.5-2 ACUs)
- NAT Gateways: ~$30-45 (3 gateways)
- ALB: ~$20-30 (2 load balancers)
- EFS: ~$5-10
- **Total: ~$135-235/month**

To reduce costs:
- Use single NAT Gateway (modify VPC stack)
- Reduce Aurora max ACUs
- Use Fargate Spot for non-critical services

## Directory Structure

```
cloudformation/aws-ecs/
├── main-stack.yaml           # Parent stack
├── parameters.json.example   # Example parameters
├── README.md                 # This file
├── templates/                # Nested stack templates
│   ├── vpc-stack.yaml
│   ├── security-groups-stack.yaml
│   ├── efs-stack.yaml
│   ├── database-stack.yaml
│   ├── secrets-stack.yaml
│   ├── iam-stack.yaml
│   ├── ecr-stack.yaml
│   ├── ecs-cluster-stack.yaml
│   ├── alb-stack.yaml
│   ├── dns-stack.yaml
│   ├── ecs-services-stack.yaml
│   └── autoscaling-stack.yaml
├── scripts/                  # Deployment scripts
│   ├── deploy.sh
│   ├── delete.sh
│   └── validate.sh
└── tests/                    # Validation tests
    ├── conftest.py
    └── test_properties.py
```

## License

See the [LICENSE](../../LICENSE) file for details.
