# MCP Gateway Registry - AWS CloudFormation Deployment

Production-grade infrastructure for the MCP Gateway Registry using AWS CloudFormation with ECS Fargate, Aurora Serverless, and Keycloak authentication.

[![Infrastructure](https://img.shields.io/badge/infrastructure-cloudformation-orange)](https://aws.amazon.com/cloudformation/)
[![AWS ECS](https://img.shields.io/badge/compute-ECS%20Fargate-orange)](https://aws.amazon.com/ecs/)
[![Database](https://img.shields.io/badge/database-Aurora%20Serverless%20v2-blue)](https://aws.amazon.com/rds/aurora/)

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment](#deployment)
- [Currently Deployed Resources](#currently-deployed-resources)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Architecture

The infrastructure uses 5 consolidated CloudFormation templates:

```
┌─────────────────────────────────────────────────────────────────┐
│                     main-stack.yaml                              │
│                   (Parent/Root Stack)                            │
├─────────────────────────────────────────────────────────────────┤
│  Nested Stacks (4 total):                                       │
│    ├── network-stack.yaml   (VPC, Subnets, NAT, SGs, VPC EP)   │
│    ├── data-stack.yaml      (EFS, Aurora, RDS Proxy, Secrets)  │
│    ├── compute-stack.yaml   (ECS Clusters, ALBs, DNS, ECR)     │
│    └── services-stack.yaml  (Task Defs, Services, AutoScale)   │
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
| Travel Assistant Agent | 9000 | A2A Agent |

## Prerequisites

### Required Tools

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| AWS CLI | >= 2.0 | [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| cfn-lint | Latest | `pip install cfn-lint` |

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

### Domain Configuration

You need a domain with a Route53 hosted zone. The infrastructure creates:
- `registry.{region}.{base_domain}` - Main registry endpoint
- `kc.{region}.{base_domain}` - Keycloak endpoint

## Quick Start

### Deploy Individual Stacks (Recommended for Testing)

The stacks use cross-stack references (`!ImportValue`) to automatically pull values from previously deployed stacks. This means you only need to specify the `EnvironmentName` parameter (which must match across all stacks).

```bash
# 1. Deploy Network Stack
aws cloudformation create-stack \
  --stack-name mcp-gateway-network \
  --template-body file://templates/network-stack.yaml \
  --region us-west-2

aws cloudformation wait stack-create-complete \
  --stack-name mcp-gateway-network --region us-west-2

# 2. Deploy Data Stack (uses ImportValue from network stack)
aws cloudformation create-stack \
  --stack-name mcp-gateway-data \
  --template-body file://templates/data-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2

aws cloudformation wait stack-create-complete \
  --stack-name mcp-gateway-data --region us-west-2

# 3. Deploy Compute Stack (uses ImportValue from network + data stacks)
aws cloudformation create-stack \
  --stack-name mcp-gateway-compute \
  --template-body file://templates/compute-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2

aws cloudformation wait stack-create-complete \
  --stack-name mcp-gateway-compute --region us-west-2

# 4. Deploy Services Stack (uses ImportValue from all previous stacks)
aws cloudformation create-stack \
  --stack-name mcp-gateway-services \
  --template-body file://templates/services-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2
```

### With Custom Domain (Optional)

To enable HTTPS with custom domain names, add these parameters to the compute stack:

```bash
aws cloudformation create-stack \
  --stack-name mcp-gateway-compute \
  --template-body file://templates/compute-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=BaseDomain,ParameterValue=mycorp.click \
    ParameterKey=HostedZoneId,ParameterValue=Z1234567890ABC \
  --region us-west-2
```

## Deployment

### Stack Deployment Order

1. **network-stack** - VPC, subnets, security groups
2. **data-stack** - EFS, Aurora, secrets (depends on network)
3. **compute-stack** - ECS clusters, ALBs, DNS (depends on network + data)
4. **services-stack** - ECS services (depends on all above)

### Full Deployment with Main Stack

For production deployment using nested stacks:

```bash
# 1. Upload templates to S3
aws s3 cp templates/ s3://<YOUR_BUCKET>/cloudformation/templates/ --recursive

# 2. Deploy main stack
aws cloudformation create-stack \
  --stack-name mcp-gateway \
  --template-body file://templates/main-stack.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=mcp-gateway \
    ParameterKey=BaseDomain,ParameterValue=<YOUR_DOMAIN> \
    ParameterKey=HostedZoneId,ParameterValue=<HOSTED_ZONE_ID> \
    ParameterKey=KeycloakDatabasePassword,ParameterValue=<PASSWORD> \
    ParameterKey=KeycloakAdminPassword,ParameterValue=<ADMIN_PASSWORD> \
    ParameterKey=TemplateS3Bucket,ParameterValue=<YOUR_BUCKET> \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2
```

## Currently Deployed Resources

**Target Region: us-west-2**

### Stack Status

| Stack Name | Status | Description |
|------------|--------|-------------|
| mcp-gateway-network | ✅ DEPLOYED | VPC, Subnets, Security Groups |
| mcp-gateway-data | ✅ DEPLOYED | EFS, Aurora, RDS Proxy, Secrets |
| mcp-gateway-compute | ⏳ NOT DEPLOYED | Requires Route53 hosted zone |
| mcp-gateway-services | ⏳ NOT DEPLOYED | Requires compute stack |

### Network Stack Resources (mcp-gateway-network)

| Resource | ID |
|----------|-----|
| VPC | `vpc-04900b8315707977b` |
| Public Subnet 1 | `subnet-044c234fcf392115e` |
| Public Subnet 2 | `subnet-0370c083e05990200` |
| Public Subnet 3 | `subnet-0a771b97005f799ee` |
| Private Subnet 1 | `subnet-0735428ee0dc664e2` |
| Private Subnet 2 | `subnet-0cc9ccf88b4b23876` |
| Private Subnet 3 | `subnet-03595bec2f9489584` |
| Main ALB SG | `sg-084a0f5cd6171750e` |
| Keycloak ALB SG | `sg-02d6951014263e980` |
| ECS Tasks SG | `sg-0db1f3db0858d21c5` |
| Keycloak ECS SG | `sg-08da55df90e59d9ea` |
| Database SG | `sg-0a03d7ea74ab53254` |
| EFS SG | `sg-03b82c1398b75f7cb` |
| MCP Servers SG | `sg-0b404804a88590f95` |

### Data Stack Resources (mcp-gateway-data)

| Resource | Value |
|----------|-------|
| EFS File System | `fs-0a3a37bef4e84ee90` |
| Aurora Cluster Endpoint | `mcp-gateway-keycloak.cluster-c5dv9t0nitzc.us-west-2.rds.amazonaws.com` |
| RDS Proxy Endpoint | `mcp-gateway-keycloak-proxy.proxy-c5dv9t0nitzc.us-west-2.rds.amazonaws.com` |

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| EnvironmentName | Prefix for all resources | mcp-gateway |
| VpcCidr | VPC CIDR block | 10.0.0.0/16 |
| BaseDomain | Base domain for regional URLs | (required) |
| HostedZoneId | Route53 hosted zone ID | (required) |
| KeycloakDatabasePassword | Database password | (required, NoEcho) |
| KeycloakAdminPassword | Keycloak admin password | (required, NoEcho) |
| EnableAutoScaling | Enable ECS auto scaling | true |
| MinCapacity | Minimum ECS tasks | 1 |
| MaxCapacity | Maximum ECS tasks | 4 |
| DatabaseMinACU | Aurora min capacity | 0.5 |
| DatabaseMaxACU | Aurora max capacity | 2 |

## Troubleshooting

### Stack Creation Failed

```bash
# View stack events
aws cloudformation describe-stack-events \
  --stack-name mcp-gateway-network \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
  --region us-west-2
```

### Certificate Validation Stuck

ACM certificates require DNS validation. Ensure your Route53 hosted zone is properly configured:
```bash
dig NS mycorp.click +short
```

### ECS Tasks Not Starting

Check CloudWatch logs:
```bash
aws logs tail /ecs/mcp-gateway-registry --follow --region us-west-2
```

### Database Connection Issues

Verify security group rules allow traffic from ECS tasks to RDS Proxy on port 3306.

## Cleanup

Delete stacks in reverse order:

```bash
# Delete services first
aws cloudformation delete-stack --stack-name mcp-gateway-services --region us-west-2
aws cloudformation wait stack-delete-complete --stack-name mcp-gateway-services --region us-west-2

# Delete compute
aws cloudformation delete-stack --stack-name mcp-gateway-compute --region us-west-2
aws cloudformation wait stack-delete-complete --stack-name mcp-gateway-compute --region us-west-2

# Delete data (Aurora deletion takes ~10 minutes)
aws cloudformation delete-stack --stack-name mcp-gateway-data --region us-west-2
aws cloudformation wait stack-delete-complete --stack-name mcp-gateway-data --region us-west-2

# Delete network
aws cloudformation delete-stack --stack-name mcp-gateway-network --region us-west-2
aws cloudformation wait stack-delete-complete --stack-name mcp-gateway-network --region us-west-2
```

## Directory Structure

```
cloudformation/aws-ecs/
├── templates/
│   ├── network-stack.yaml    # VPC, subnets, NAT, security groups
│   ├── data-stack.yaml       # EFS, Aurora, RDS Proxy, Secrets
│   ├── compute-stack.yaml    # ECS clusters, ALBs, DNS, IAM
│   ├── services-stack.yaml   # ECS services, task definitions
│   └── main-stack.yaml       # Parent orchestration
├── parameters.json.example   # Example parameter file
└── README.md                 # This file
```

## License

See the [LICENSE](../../LICENSE) file for details.
