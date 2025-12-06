# Terraform to CloudFormation Configuration Comparison

This document tracks the systematic comparison of all Terraform configurations against CloudFormation templates to ensure parity.

## Deployment Status

**Last Updated:** December 6, 2025

| Stack | Status | Notes |
|-------|--------|-------|
| mcp-gateway-network | ✅ DEPLOYED | VPC, subnets, security groups |
| mcp-gateway-data | ✅ DEPLOYED | EFS, Aurora, RDS Proxy, Secrets, SSM |
| mcp-gateway-compute | ✅ DEPLOYED | ECS clusters, ALBs, ECR, IAM, CodeBuild |
| mcp-gateway-services | ✅ DEPLOYED | All 8 ECS services running (1/1 each) |

**All services verified healthy:**
- Main ALB: `http://mcp-gateway-alb-540864537.us-west-2.elb.amazonaws.com`
- Keycloak ALB: `http://mcp-gateway-keycloak-alb-1578958238.us-west-2.elb.amazonaws.com`

---

## Comparison Status Legend
- ✅ Verified Match
- ❌ Mismatch - Needs Fix
- ⚠️ Different but Acceptable
- 🔍 Not Yet Compared

---

## 1. Auth Server

### 1.1 Task Definition
| Config | Terraform (`ecs-services.tf`) | CloudFormation (`services-stack.yaml`) | Status |
|--------|-------------------------------|----------------------------------------|--------|
| CPU | `tonumber(var.cpu)` = 1024 | `!Ref ServiceCpu` = 1024 | ✅ |
| Memory | `tonumber(var.memory)` = 2048 | `!Ref ServiceMemory` = 2048 | ✅ |
| Network Mode | awsvpc | awsvpc | ✅ |
| Launch Type | FARGATE | FARGATE | ✅ |
| Container Name | auth-server | auth-server | ✅ |

### 1.2 Container Port Mappings
| Port | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| 8888 | ✓ (name: auth-server) | ✓ (name: auth-server) | ✅ |

### 1.3 Environment Variables
| Variable | Terraform | CloudFormation | Status |
|----------|-----------|----------------|--------|
| REGISTRY_URL | `https://${var.domain_name}` | `!ImportValue RegistryUrl` | ✅ |
| AUTH_SERVER_URL | `http://auth-server:8888` | `http://auth-server:8888` | ✅ |
| AUTH_SERVER_EXTERNAL_URL | `https://${var.domain_name}` | `!ImportValue RegistryUrl` | ✅ |
| AWS_REGION | `data.aws_region.current.id` | `!Ref AWS::Region` | ✅ |
| AUTH_PROVIDER | `keycloak` (conditional) | `keycloak` | ✅ |
| KEYCLOAK_URL | `https://${var.keycloak_domain}` | `!ImportValue KeycloakUrl` | ✅ |
| KEYCLOAK_EXTERNAL_URL | `https://${var.keycloak_domain}` | `!ImportValue KeycloakUrl` | ✅ |
| KEYCLOAK_REALM | `mcp-gateway` | `mcp-gateway` | ✅ |
| KEYCLOAK_CLIENT_ID | `mcp-gateway-web` | `mcp-gateway-web` | ✅ |
| SCOPES_CONFIG_PATH | `/efs/auth_config/auth_config/scopes.yml` | `/efs/auth_config/auth_config/scopes.yml` | ✅ |

### 1.4 Secrets
| Secret | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| SECRET_KEY | `aws_secretsmanager_secret.secret_key.arn` | `!ImportValue SecretKeySecretArn` | ✅ |
| KEYCLOAK_CLIENT_SECRET | `${secret.arn}:client_secret::` | `${SecretArn}:client_secret::` | ✅ |

### 1.5 EFS Volumes
| Volume | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| mcp-logs | ✓ (access_points["logs"]) | ✓ (EfsAccessPointLogs) | ✅ |
| auth-config | ✓ (access_points["auth_config"]) | ✓ (EfsAccessPointAuthConfig) | ✅ |

### 1.6 Mount Points
| Path | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| /app/logs | mcp-logs, readOnly=false | mcp-logs, ReadOnly=false | ✅ |
| /efs/auth_config | auth-config, readOnly=false | auth-config, ReadOnly=false | ✅ |

### 1.7 Health Check
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Command | `curl -f http://localhost:8888/health \|\| exit 1` | `curl -f http://localhost:8888/health \|\| exit 1` | ✅ |
| Interval | 30 | 30 | ✅ |
| Timeout | 5 | 5 | ✅ |
| Retries | 3 | 3 | ✅ |
| StartPeriod | 60 | 60 | ✅ |

### 1.8 Log Configuration
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Log Driver | awslogs | awslogs | ✅ |
| Log Group | `/ecs/${local.name_prefix}-auth-server` | `/ecs/${EnvironmentName}-auth-server` | ✅ |
| Retention | 30 days | 30 days | ✅ |
| Stream Prefix | ecs | ecs | ✅ |

### 1.9 Service Configuration
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Enable Execute Command | true | true | ✅ |
| Assign Public IP | false (private subnets) | DISABLED | ✅ |
| Target Group | auth target group | AuthTargetGroupArn | ✅ |
| Service Connect | ✓ (port 8888, dns: auth-server) | ✓ (port 8888, dns: auth-server) | ✅ |

---

## 2. Registry

### 2.1 Task Definition
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| CPU | 1024 | 1024 | ✅ |
| Memory | 2048 | 2048 | ✅ |
| Network Mode | awsvpc | awsvpc | ✅ |
| Launch Type | FARGATE | FARGATE | ✅ |
| Container Name | registry | registry | ✅ |

### 2.2 Container Port Mappings
| Port | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| 80 (http) | ✓ | ✓ | ✅ |
| 443 (https) | ✓ | ✓ | ✅ |
| 7860 (registry) | ✓ | ✓ | ✅ |

### 2.3 Environment Variables
| Variable | Terraform | CloudFormation | Status |
|----------|-----------|----------------|--------|
| GATEWAY_ADDITIONAL_SERVER_NAMES | `var.domain_name` | `!ImportValue MainAlbDnsName` | ✅ |
| EC2_PUBLIC_DNS | `var.domain_name` or `module.alb.dns_name` | `!ImportValue MainAlbDnsName` | ✅ |
| AUTH_SERVER_URL | `http://auth-server:8888` | `http://auth-server:8888` | ✅ |
| AUTH_SERVER_EXTERNAL_URL | `https://${var.domain_name}:8888` | `${RegistryUrl}:8888` | ✅ |
| KEYCLOAK_URL | `https://${var.keycloak_domain}` | `!ImportValue KeycloakUrl` | ✅ |
| KEYCLOAK_ENABLED | `true` (conditional) | `true` | ✅ |
| KEYCLOAK_REALM | `mcp-gateway` | `mcp-gateway` | ✅ |
| KEYCLOAK_CLIENT_ID | `mcp-gateway-web` | `mcp-gateway-web` | ✅ |
| AUTH_PROVIDER | `keycloak` (conditional) | `keycloak` | ✅ |
| AWS_REGION | `data.aws_region.current.id` | `!Ref AWS::Region` | ✅ |
| SCOPES_CONFIG_PATH | `/app/auth_server/scopes.yml` | `/app/auth_server/scopes.yml` | ✅ |

### 2.4 Secrets
| Secret | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| SECRET_KEY | ✓ | ✓ | ✅ |
| ADMIN_PASSWORD | ✓ | ✓ | ✅ |
| KEYCLOAK_CLIENT_SECRET | ✓ (:client_secret::) | ✓ (:client_secret::) | ✅ |
| KEYCLOAK_M2M_CLIENT_SECRET | ✓ (:client_secret::) | ✓ (:client_secret::) | ✅ |

### 2.5 EFS Volumes
| Volume | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| mcp-servers | ✓ | ✓ | ✅ |
| mcp-agents | ✓ | ✓ | ✅ |
| mcp-models | ✓ | ✓ | ✅ |
| mcp-logs | ✓ | ✓ | ✅ |
| auth-config | ✓ | ✓ | ✅ |

### 2.6 Mount Points
| Path | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| /app/registry/servers | mcp-servers | mcp-servers | ✅ |
| /app/registry/agents | mcp-agents | mcp-agents | ✅ |
| /app/registry/models | mcp-models | mcp-models | ✅ |
| /app/logs | mcp-logs | mcp-logs | ✅ |
| /app/auth_server | auth-config | auth-config | ✅ |

### 2.7 Health Check
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Command | `curl -f http://localhost:7860/health \|\| exit 1` | `curl -f http://localhost:7860/health \|\| exit 1` | ✅ |
| Interval | 30 | 30 | ✅ |
| Timeout | 5 | 5 | ✅ |
| Retries | 3 | 3 | ✅ |
| StartPeriod | 60 | 60 | ✅ |

### 2.8 Log Configuration
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Retention | 30 days | 30 days | ✅ |

### 2.9 Service Configuration
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| DependsOn | auth service | AuthServerService | ✅ |
| Load Balancers | registry + gradio target groups | RegistryTargetGroupArn + GradioTargetGroupArn | ✅ |
| Service Connect | port 7860, dns: registry | port 7860, dns: registry | ✅ |

---

## 3. Keycloak

### 3.1 Task Definition
| Config | Terraform (`keycloak-ecs.tf`) | CloudFormation | Status |
|--------|-------------------------------|----------------|--------|
| CPU | 1024 | 1024 | ✅ |
| Memory | 2048 | 2048 | ✅ |
| Network Mode | awsvpc | awsvpc | ✅ |
| Launch Type | FARGATE | FARGATE | ✅ |
| Container Name | keycloak | keycloak | ✅ |

### 3.2 Container Port Mappings
| Port | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| 8080 (keycloak) | ✓ | ✓ | ✅ |
| 9000 (keycloak-management) | ✓ | ✓ | ✅ FIXED |

### 3.3 Environment Variables
| Variable | Terraform | CloudFormation | Status |
|----------|-----------|----------------|--------|
| AWS_REGION | ✓ | ✓ | ✅ FIXED |
| KC_PROXY | `edge` | `edge` | ✅ FIXED |
| KC_PROXY_ADDRESS_FORWARDING | `true` | `true` | ✅ FIXED |
| KC_HOSTNAME | ✓ | ✓ | ✅ |
| KC_HOSTNAME_STRICT | `false` | `false` | ✅ |
| KC_HOSTNAME_STRICT_HTTPS | `false` | `false` | ✅ FIXED |
| KC_HEALTH_ENABLED | `true` | `true` | ✅ |
| KC_METRICS_ENABLED | `true` | `true` | ✅ |
| KEYCLOAK_LOGLEVEL | `var.keycloak_log_level` | `!Ref KeycloakLogLevel` | ✅ FIXED |

### 3.4 Secrets
| Secret | Terraform (SSM) | CloudFormation (SSM) | Status |
|--------|-----------------|----------------------|--------|
| KEYCLOAK_ADMIN | `/keycloak/admin` | `/keycloak/admin` | ✅ FIXED |
| KEYCLOAK_ADMIN_PASSWORD | `/keycloak/admin_password` | `/keycloak/admin_password` | ✅ FIXED |
| KC_DB_URL | `/keycloak/database/url` | `/keycloak/database/url` | ✅ FIXED |
| KC_DB_USERNAME | `/keycloak/database/username` | `/keycloak/database/username` | ✅ FIXED |
| KC_DB_PASSWORD | `/keycloak/database/password` | `/keycloak/database/password` | ✅ FIXED |

### 3.5 Health Check
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Command | `exit 0` | `exit 0` | ✅ |
| Interval | 30 | 30 | ✅ |
| Timeout | 5 | 5 | ✅ |
| Retries | 3 | 3 | ✅ |
| StartPeriod | 60 | 60 | ✅ |

### 3.6 Log Configuration
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Log Group | `/ecs/keycloak` | `/ecs/${EnvironmentName}-keycloak` | ⚠️ Slightly different |
| Retention | 7 days | 7 days | ✅ |

### 3.7 Service Configuration
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Cluster | keycloak cluster | KeycloakEcsClusterArn | ✅ |
| Desired Count | 1 | 1 | ✅ |
| Target Group | keycloak target group | KeycloakTargetGroupArn | ✅ |
| Service Connect | ✗ | ✗ | ✅ (neither has it) |

### 3.8 Auto Scaling
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Enabled | ✓ | ✓ | ✅ FIXED |
| Min Capacity | 1 | 1 | ✅ FIXED |
| Max Capacity | 4 | 4 | ✅ FIXED |
| CPU Target | 70% | 70% | ✅ FIXED |
| Memory Target | 80% | 80% | ✅ FIXED |

---

## 4. CurrentTime MCP Server

### 4.1 Task Definition
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| CPU | 512 | 512 | ✅ |
| Memory | 1024 | 1024 | ✅ |

### 4.2 Port Mappings
| Port | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| 8000 | ✓ | ✓ | ✅ |

### 4.3 Environment Variables
| Variable | Terraform | CloudFormation | Status |
|----------|-----------|----------------|--------|
| PORT | 8000 | 8000 | ✅ |
| MCP_TRANSPORT | streamable-http | streamable-http | ✅ |

### 4.4 Health Check
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Command | `nc -z localhost 8000 \|\| exit 1` | `nc -z localhost 8000 \|\| exit 1` | ✅ |
| StartPeriod | 30 | 30 | ✅ |

### 4.5 Service Connect
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Port | 8000 | 8000 | ✅ |
| DNS Name | currenttime-server | currenttime-server | ✅ |

---

## 5. MCPGW MCP Server

### 5.1 Task Definition
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| CPU | 512 | 512 | ✅ |
| Memory | 1024 | 1024 | ✅ |

### 5.2 Port Mappings
| Port | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| 8003 | ✓ | ✓ | ✅ |

### 5.3 Environment Variables
| Variable | Terraform | CloudFormation | Status |
|----------|-----------|----------------|--------|
| PORT | 8003 | 8003 | ✅ |
| REGISTRY_BASE_URL | http://registry:7860 | http://registry:7860 | ✅ |
| REGISTRY_USERNAME | admin | admin | ✅ |

### 5.4 Secrets
| Secret | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| REGISTRY_PASSWORD | admin_password secret | AdminPasswordSecretArn | ✅ |

### 5.5 EFS Volumes
| Volume | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| mcpgw-data | ✓ (mcpgw_data access point) | ✓ (EfsAccessPointMcpgwData) | ✅ |

### 5.6 Health Check
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Command | `nc -z localhost 8003 \|\| exit 1` | `nc -z localhost 8003 \|\| exit 1` | ✅ |
| StartPeriod | 30 | 30 | ✅ |

---

## 6. RealServerFakeTools MCP Server

### 6.1 Task Definition
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| CPU | 512 | 512 | ✅ |
| Memory | 1024 | 1024 | ✅ |

### 6.2 Port Mappings
| Port | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| 8002 | ✓ | ✓ | ✅ |

### 6.3 Environment Variables
| Variable | Terraform | CloudFormation | Status |
|----------|-----------|----------------|--------|
| PORT | 8002 | 8002 | ✅ |
| MCP_TRANSPORT | streamable-http | streamable-http | ✅ |

### 6.4 Health Check
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Command | `nc -z localhost 8002 \|\| exit 1` | `nc -z localhost 8002 \|\| exit 1` | ✅ |
| StartPeriod | 30 | 30 | ✅ |

---

## 7. Flight Booking Agent

### 7.1 Task Definition
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| CPU | 512 | 512 | ✅ |
| Memory | 1024 | 1024 | ✅ |

### 7.2 Port Mappings
| Port | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| 9000 | ✓ | ✓ | ✅ |

### 7.3 Environment Variables
| Variable | Terraform | CloudFormation | Status |
|----------|-----------|----------------|--------|
| AWS_REGION | ✓ | ✓ | ✅ |
| AWS_DEFAULT_REGION | ✓ | ✓ | ✅ |

### 7.4 Health Check
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Command | `curl -f http://localhost:9000/ping \|\| exit 1` | `curl -f http://localhost:9000/ping \|\| exit 1` | ✅ |
| StartPeriod | 60 | 60 | ✅ |

---

## 8. Travel Assistant Agent

### 8.1 Task Definition
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| CPU | 512 | 512 | ✅ |
| Memory | 1024 | 1024 | ✅ |

### 8.2 Port Mappings
| Port | Terraform | CloudFormation | Status |
|------|-----------|----------------|--------|
| 9000 | ✓ | ✓ | ✅ |

### 8.3 Environment Variables
| Variable | Terraform | CloudFormation | Status |
|----------|-----------|----------------|--------|
| AWS_REGION | ✓ | ✓ | ✅ |
| AWS_DEFAULT_REGION | ✓ | ✓ | ✅ |

### 8.4 Health Check
| Config | Terraform | CloudFormation | Status |
|--------|-----------|----------------|--------|
| Command | `curl -f http://localhost:9000/ping \|\| exit 1` | `curl -f http://localhost:9000/ping \|\| exit 1` | ✅ |
| StartPeriod | 60 | 60 | ✅ |

---

## Summary of Issues Found

### All Issues Fixed ✅

All Keycloak configuration has been updated to match Terraform exactly:

1. ✅ **Keycloak port 9000** - Added management port
2. ✅ **KC_HOSTNAME_STRICT_HTTPS=false** - Added
3. ✅ **Keycloak auto scaling** - Added with min=1, max=4, CPU=70%, Memory=80%
4. ✅ **AWS_REGION** - Added to environment
5. ✅ **KEYCLOAK_LOGLEVEL** - Added with parameter (default: INFO)
6. ✅ **KC_PROXY=edge** - Changed from KC_PROXY_HEADERS to match Terraform
7. ✅ **KC_PROXY_ADDRESS_FORWARDING=true** - Added
8. ✅ **Secrets source** - Changed from Secrets Manager to SSM parameters to match Terraform

---

## Action Items

- [x] Add Keycloak port 9000 mapping
- [x] Add KC_HOSTNAME_STRICT_HTTPS=false to Keycloak
- [x] Add AWS_REGION to Keycloak environment
- [x] Add KEYCLOAK_LOGLEVEL to Keycloak environment (default: INFO)
- [x] Add Keycloak auto scaling (ScalableTarget + ScalingPolicies)
- [x] Change KC_PROXY_HEADERS to KC_PROXY=edge + KC_PROXY_ADDRESS_FORWARDING=true
- [x] Change secrets from Secrets Manager to SSM parameters
- [x] Add SSM parameters for Keycloak admin credentials to data-stack
- [x] Export SSM parameter ARNs from data-stack

---

## Files Modified

1. `cloudformation/aws-ecs/templates/data-stack.yaml`
   - Added SSM parameters: `/keycloak/admin`, `/keycloak/admin_password`
   - Added exports for all Keycloak SSM parameter ARNs

2. `cloudformation/aws-ecs/templates/services-stack.yaml`
   - Updated Keycloak task definition to match Terraform exactly
   - Added KeycloakLogLevel parameter
   - Added Keycloak auto scaling (ScalableTarget + CPU/Memory policies)
