# MCP Gateway Registry - AWS CloudFormation Workshop Deployment

Production-grade infrastructure for the MCP Gateway Registry using AWS CloudFormation with ECS Fargate, DocumentDB, ECS Service Connect, and Keycloak authentication.

[![Infrastructure](https://img.shields.io/badge/infrastructure-cloudformation-orange)](https://aws.amazon.com/cloudformation/)
[![AWS ECS](https://img.shields.io/badge/compute-ECS%20Fargate-orange)](https://aws.amazon.com/ecs/)
[![Database](https://img.shields.io/badge/database-DocumentDB-blue)](https://aws.amazon.com/documentdb/)

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [Build Strategy](#build-strategy)
- [Configuration](#configuration)
- [Service Connect Networking](#service-connect-networking)
- [Registration Flow](#registration-flow)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Architecture

The infrastructure uses 7 CloudFormation templates deployed as a nested stack:

```
main-stack.yaml (Parent/Root Stack)
  |
  |-- network-stack.yaml        VPC, Subnets, NAT Gateway, Security Groups
  |-- data-stack.yaml           DocumentDB, Keycloak Aurora PostgreSQL, Secrets Manager
  |-- compute-stack.yaml        ECS Cluster, CodeBuild, ECR, CloudFront, ALBs
  |-- services-stack.yaml       ECS Services, Task Definitions, Service Connect
  |-- observability-stack.yaml  Grafana OSS, ADOT Collector, Amazon Managed Prometheus
  |-- workshop-tools-stack.yaml Load Generator, Network Health Check, MCP Registration
```

### Services Deployed

| Service | Container Port | Description |
|---------|---------------|-------------|
| Registry | 7860 | MCP Gateway Registry (main application) |
| Auth Server | 8888 | OAuth2/OIDC token proxy |
| Keycloak | 8080 | Identity and Access Management |
| CurrentTime MCP | 8000 | Example MCP server |
| MCPGW | 8003 | MCP Gateway protocol server (backend for airegistry-tools) |
| RealServerFakeTools | 8002 | Example MCP server with simulated tools |
| Flight Booking Agent | 9000 | A2A demo agent |
| Travel Assistant Agent | 9000 | A2A demo agent |
| Metrics Service | 9465 | Prometheus metrics collector |
| Grafana | 3000 | Observability dashboards |

### External Access

| Endpoint | Method | Description |
|----------|--------|-------------|
| Registry UI | CloudFront | HTTPS access to the Registry dashboard |
| Keycloak Admin | CloudFront | HTTPS access to Keycloak admin console |
| Grafana | ALB | HTTP access to Grafana dashboards |

## Prerequisites

### Required Tools

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| AWS CLI | >= 2.0 | Stack deployment and management |

### AWS Account Setup

The deployment creates all required infrastructure. You need an AWS account with permissions to create:
- VPC, Subnets, NAT Gateways, Internet Gateways
- ECS Clusters, Task Definitions, Services (with Service Connect)
- DocumentDB Clusters
- RDS Aurora Clusters (for Keycloak)
- Application Load Balancers, CloudFront Distributions
- CodeBuild Projects, ECR Repositories
- IAM Roles and Policies
- Secrets Manager Secrets, SSM Parameters
- Cloud Map Namespaces (HTTP type, for Service Connect)

## Deployment

### Workshop Deployment (Nested Stacks via main-stack)

For workshop use, all templates are uploaded to S3 and deployed as a single nested stack:

```bash
# 1. Upload templates to S3
aws s3 cp templates/ s3://<TEMPLATE_BUCKET>/cloudformation/templates/ --recursive

# 2. Deploy the main stack
aws cloudformation create-stack \
  --stack-name mcp-gateway \
  --template-body file://templates/main-stack.yaml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=mcp-gateway \
    ParameterKey=TemplateS3Bucket,ParameterValue=<TEMPLATE_BUCKET> \
    ParameterKey=KeycloakDatabasePassword,ParameterValue=<PASSWORD> \
    ParameterKey=KeycloakAdminPassword,ParameterValue=<ADMIN_PASSWORD> \
    ParameterKey=DocumentDBPassword,ParameterValue=<DB_PASSWORD> \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-2
```

### Stack Deployment Order (Automatic via Nested Stacks)

The main stack deploys nested stacks in dependency order:

1. **NetworkStack** - VPC, subnets, security groups
2. **DataStack** - DocumentDB, Keycloak Aurora, Secrets Manager (depends on Network)
3. **ComputeStack** - ECS cluster, CodeBuild, ECR, CloudFront, ALBs (depends on Network + Data)
4. **ServicesStack** - ECS services with Service Connect (depends on all above)
5. **ObservabilityStack** - Grafana, ADOT, Prometheus (depends on Services)
6. **WorkshopToolsStack** - Network health gate, MCP registration, load generator (depends on Services)

### Individual Stack Deployment (Development/Testing)

Stacks use cross-stack references (`!ImportValue`) and can be deployed individually:

```bash
# Deploy each stack in order (EnvironmentName must match across all stacks)
aws cloudformation create-stack \
  --stack-name mcp-gateway-network \
  --template-body file://templates/network-stack.yaml \
  --region us-east-2

aws cloudformation wait stack-create-complete \
  --stack-name mcp-gateway-network --region us-east-2

# Continue with data-stack, compute-stack, services-stack, etc.
```

## Build Strategy

Container images are built via CodeBuild from the GitHub repository source.

### Development Phase (Current)

The `build-containers-workshop.sh` script triggers CodeBuild to:
1. Clone the repository (`cloudformation/workshop-v1.0.16` branch)
2. Build all 10 container images in parallel
3. Push dual-tagged images to ECR (`latest` + git SHA)

```bash
# Trigger a container build
./scripts/build-containers-workshop.sh
```

### Stable Phase (Future)

For production workshops, pre-built container tarballs are exported to S3:

```bash
# Export containers as split tarballs to S3
./scripts/export-containers.sh
```

The compute-stack CodeBuild switches to `NO_SOURCE` and imports from S3.

## Configuration

### Key Parameters (main-stack.yaml)

| Parameter | Description | Default |
|-----------|-------------|---------|
| EnvironmentName | Prefix for all resources | `mcp-gateway` |
| TemplateS3Bucket | S3 bucket containing nested templates | (required) |
| KeycloakDatabasePassword | Keycloak Aurora password | (required, NoEcho) |
| KeycloakAdminPassword | Keycloak admin password | (required, NoEcho) |
| DocumentDBPassword | DocumentDB cluster password | (required, NoEcho) |
| VpcCidr | VPC CIDR block | `10.0.0.0/16` |

See `parameters.json.example` for a complete parameter reference.

## Service Connect Networking

All ECS services communicate via **ECS Service Connect** (Envoy sidecar proxy), not DNS-based Cloud Map.

### How It Works

- A Cloud Map **HTTP namespace** (`mcp-gateway.local`) is created in the compute stack
- Each ECS service registers a `portMapping.name` and `serviceConnectConfiguration`
- The Envoy sidecar intercepts traffic and routes by hostname
- Hostnames like `mcpgw-server:8003`, `currenttime-server:8000` resolve automatically within the ECS cluster

### Important: Propagation Delay

Service Connect hostnames take approximately **10-15 minutes** to propagate after ECS services reach `CREATE_COMPLETE`. The `ServiceNetworkHealthCheck` Lambda in `workshop-tools-stack.yaml` gates downstream operations until connectivity is confirmed.

## Registration Flow

After deployment, two Lambdas in the workshop-tools-stack handle registration:

### 1. ServiceNetworkHealthCheck

- **Purpose:** Confirm Service Connect is fully propagated
- **Method:** Polls `GET /api/tools/airegistry-tools/` for discovered tools > 0
- **Triggers:** `POST /api/refresh/airegistry-tools/` each attempt to retry tool discovery
- **Timeout:** 600 seconds (polls with increasing backoff)

### 2. MCPRegistrationLambda (DependsOn: ServiceNetworkHealthCheck)

- **Purpose:** Register MCP servers, A2A agents, virtual servers, and skills
- **Runs only after** Service Connect is confirmed working
- **Registers:**
  - MCP servers: `/currenttime/`, `/realserverfaketools/`
  - A2A agents: Flight Booking, Travel Assistant
  - Virtual server: "Dev Tools" (maps `intelligent_tool_finder` to `/airegistry-tools/`)
  - Skills: weather lookup, unit conversion

The built-in `/airegistry-tools/` server (backed by `mcpgw-server:8003`) is auto-registered by the Registry on startup and does not need Lambda registration.

## Troubleshooting

### Stack Creation Failed

```bash
# View failure events for the main stack and nested stacks
aws cloudformation describe-stack-events \
  --stack-name mcp-gateway \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
  --output table --region us-east-2
```

### ECS Services Not Healthy

```bash
# Check registry logs
aws logs tail /ecs/mcp-gateway-registry --follow --region us-east-2

# Check Service Connect health (look for tool discovery)
aws logs tail /ecs/mcp-gateway-registry --filter-pattern "airegistry-tools" --region us-east-2
```

### Registration Lambda Failed

```bash
# Check network health check logs
aws logs tail /aws/lambda/mcp-gateway-svc-network-health --region us-east-2

# Check registration Lambda logs
aws logs tail /aws/lambda/mcp-gateway-mcp-registration --region us-east-2
```

Common causes:
- **Service Connect not ready:** The health check Lambda should handle this. If it times out after 600s, check that the Registry and MCPGW services are running.
- **M2M token failure:** Verify Keycloak is healthy and the M2M client secret in Secrets Manager is correct.

### CodeBuild Container Build Failed

```bash
# Check the latest build
aws codebuild list-builds-for-project \
  --project-name mcp-gateway-container-build \
  --query 'ids[0]' --output text --region us-east-2 | \
  xargs -I {} aws codebuild batch-get-builds --ids {} \
  --query 'builds[0].buildStatus' --output text --region us-east-2
```

Known issue: NodeSource CDN can have transient mirror sync failures causing `npm: not found`. Retry usually resolves it.

### Keycloak ALB HTTP Listener Deletion

AWS internal security automation may delete HTTP-only listeners on public ALBs in workshop accounts. If CloudFront returns 502 errors for Keycloak:

```bash
# Recreate the HTTP listener
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names mcp-gateway-keycloak-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text --region us-east-2)

TG_ARN=$(aws elbv2 describe-target-groups \
  --names mcp-gateway-keycloak-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text --region us-east-2)

aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
  --region us-east-2
```

## Cleanup

### Nested Stack Cleanup

```bash
# Delete the entire deployment (nested stacks deleted automatically)
aws cloudformation delete-stack --stack-name mcp-gateway --region us-east-2
aws cloudformation wait stack-delete-complete --stack-name mcp-gateway --region us-east-2
```

### Manual Stack Cleanup (if deployed individually)

Delete in reverse order:

```bash
for stack in workshop-tools observability services compute data network; do
  aws cloudformation delete-stack --stack-name mcp-gateway-${stack} --region us-east-2
  aws cloudformation wait stack-delete-complete --stack-name mcp-gateway-${stack} --region us-east-2
done
```

Note: DocumentDB and Aurora deletion can take 10+ minutes.

## Directory Structure

```
cloudformation/aws-ecs/
├── templates/
│   ├── main-stack.yaml             # Parent orchestration (nested stacks)
│   ├── network-stack.yaml          # VPC, subnets, NAT, security groups
│   ├── data-stack.yaml             # DocumentDB, Keycloak Aurora, Secrets
│   ├── compute-stack.yaml          # ECS cluster, CodeBuild, ECR, CloudFront, ALBs
│   ├── services-stack.yaml         # ECS services, task definitions, Service Connect
│   ├── observability-stack.yaml    # Grafana OSS, ADOT, Amazon Managed Prometheus
│   └── workshop-tools-stack.yaml   # Load generator, health check, MCP registration
├── scripts/
│   ├── build-containers-workshop.sh  # Trigger CodeBuild from GitHub source
│   ├── export-containers.sh          # Export pre-built containers to S3
│   ├── load-generator.sh             # Workshop load generator script
│   ├── generate-mcp-server-cfn.py    # CFN generator for MCP server services
│   └── tf-cfn-sync.py               # Terraform-to-CloudFormation sync tool
├── config/
│   └── adot-collector-config.yaml    # ADOT Collector scrape configuration
├── grafana/
│   ├── Dockerfile                    # Grafana OSS with pre-configured dashboards
│   ├── dashboards/                   # JSON dashboard definitions
│   └── provisioning/                 # Datasource and dashboard provisioning
├── content/                          # Workshop content (Hugo markdown)
├── static/                           # Workshop static assets and IAM policies
├── docs/                             # Architecture and requirements docs
├── tests/                            # Template validation tests
├── parameters.json.example           # Example parameter file
├── OBSERVABILITY-SETUP.md            # Observability stack setup guide
├── THIRD_PARTY_LICENSES.md           # Third-party license inventory
└── README.md                         # This file
```

## License

See the [LICENSE](../../LICENSE) file for details.
