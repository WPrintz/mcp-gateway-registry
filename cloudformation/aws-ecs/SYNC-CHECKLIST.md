# Terraform to CloudFormation Sync Checklist

Use this checklist when Terraform configurations are updated to ensure CloudFormation templates stay in sync.

## Source Files to Compare

### Terraform Files
| File | Contains |
|------|----------|
| `terraform/aws-ecs/keycloak-ecs.tf` | Keycloak task definition, service, auto scaling, SSM parameters |
| `terraform/aws-ecs/modules/mcp-gateway/ecs-services.tf` | All other ECS services (Auth, Registry, MCP servers, Agents) |
| `terraform/aws-ecs/modules/mcp-gateway/variables.tf` | Default values for CPU, memory, replicas, etc. |
| `terraform/aws-ecs/modules/mcp-gateway/storage.tf` | EFS configuration |
| `terraform/aws-ecs/modules/mcp-gateway/secrets.tf` | Secrets Manager secrets |
| `terraform/aws-ecs/modules/mcp-gateway/networking.tf` | ALB, target groups, listeners |
| `terraform/aws-ecs/modules/mcp-gateway/iam.tf` | IAM roles and policies |
| `terraform/aws-ecs/vpc.tf` | VPC, subnets, security groups |
| `terraform/aws-ecs/keycloak-database.tf` | Aurora cluster, RDS Proxy |
| `terraform/aws-ecs/keycloak-alb.tf` | Keycloak ALB configuration |

### CloudFormation Files
| File | Contains |
|------|----------|
| `cloudformation/aws-ecs/templates/network-stack.yaml` | VPC, subnets, security groups, VPC endpoints |
| `cloudformation/aws-ecs/templates/data-stack.yaml` | EFS, Aurora, RDS Proxy, Secrets, SSM parameters |
| `cloudformation/aws-ecs/templates/compute-stack.yaml` | ECS clusters, ALBs, IAM roles, ECR, CodeBuild |
| `cloudformation/aws-ecs/templates/services-stack.yaml` | Task definitions, ECS services, auto scaling |

---

## Per-Service Comparison Checklist

For each ECS service, verify the following match between Terraform and CloudFormation:

### Task Definition
- [ ] CPU units
- [ ] Memory (MB)
- [ ] Network mode (should be `awsvpc`)
- [ ] Launch type (should be `FARGATE`)
- [ ] Container name
- [ ] Image URI pattern
- [ ] `readonlyRootFilesystem` setting

### Port Mappings
- [ ] All container ports listed
- [ ] Port names match
- [ ] Host ports (if specified)

### Environment Variables
- [ ] All environment variable names present
- [ ] Values match (or use equivalent dynamic references)
- [ ] No extra/missing variables

### Secrets
- [ ] All secrets present
- [ ] Source type matches (SSM vs Secrets Manager)
- [ ] ARN/path patterns match
- [ ] JSON key extraction syntax (`:key::` format)

### EFS Volumes (if applicable)
- [ ] All volumes defined
- [ ] Access point IDs referenced correctly
- [ ] Transit encryption enabled
- [ ] Mount paths match

### Health Check
- [ ] Command matches exactly
- [ ] Interval (seconds)
- [ ] Timeout (seconds)
- [ ] Retries
- [ ] Start period (seconds)

### Log Configuration
- [ ] Log driver (awslogs)
- [ ] Log group name pattern
- [ ] Retention period (days)
- [ ] Stream prefix

### Service Configuration
- [ ] Cluster assignment (main vs keycloak)
- [ ] Desired count / min capacity
- [ ] Security group assignment
- [ ] Subnet assignment (private)
- [ ] Load balancer target groups
- [ ] Service Connect configuration (namespace, port, DNS name)
- [ ] Enable Execute Command setting
- [ ] DependsOn relationships

### Auto Scaling
- [ ] Enabled/disabled
- [ ] Min capacity
- [ ] Max capacity
- [ ] CPU target percentage
- [ ] Memory target percentage
- [ ] Scaling policy names

---

## Services to Compare

### 1. Auth Server
**Terraform:** `modules/mcp-gateway/ecs-services.tf` → `module "ecs_service_auth"`
**CloudFormation:** `services-stack.yaml` → `AuthServerTaskDefinition`, `AuthServerService`

### 2. Registry
**Terraform:** `modules/mcp-gateway/ecs-services.tf` → `module "ecs_service_registry"`
**CloudFormation:** `services-stack.yaml` → `RegistryTaskDefinition`, `RegistryService`

### 3. Keycloak
**Terraform:** `keycloak-ecs.tf` → `aws_ecs_task_definition.keycloak`, `aws_ecs_service.keycloak`
**CloudFormation:** `services-stack.yaml` → `KeycloakTaskDefinition`, `KeycloakService`

### 4. CurrentTime MCP Server
**Terraform:** `modules/mcp-gateway/ecs-services.tf` → `module "ecs_service_currenttime"`
**CloudFormation:** `services-stack.yaml` → `CurrentTimeTaskDefinition`, `CurrentTimeService`

### 5. MCPGW MCP Server
**Terraform:** `modules/mcp-gateway/ecs-services.tf` → `module "ecs_service_mcpgw"`
**CloudFormation:** `services-stack.yaml` → `McpgwTaskDefinition`, `McpgwService`

### 6. RealServerFakeTools MCP Server
**Terraform:** `modules/mcp-gateway/ecs-services.tf` → `module "ecs_service_realserverfaketools"`
**CloudFormation:** `services-stack.yaml` → `RealServerFakeToolsTaskDefinition`, `RealServerFakeToolsService`

### 7. Flight Booking Agent
**Terraform:** `modules/mcp-gateway/ecs-services.tf` → `module "ecs_service_flight_booking_agent"`
**CloudFormation:** `services-stack.yaml` → `FlightBookingAgentTaskDefinition`, `FlightBookingAgentService`

### 8. Travel Assistant Agent
**Terraform:** `modules/mcp-gateway/ecs-services.tf` → `module "ecs_service_travel_assistant_agent"`
**CloudFormation:** `services-stack.yaml` → `TravelAssistantAgentTaskDefinition`, `TravelAssistantAgentService`

---

## Infrastructure Comparison Checklist

### VPC & Networking
- [ ] VPC CIDR block
- [ ] Public subnet CIDRs (3 AZs)
- [ ] Private subnet CIDRs (3 AZs)
- [ ] NAT Gateway configuration
- [ ] VPC endpoints (STS, S3)

### Security Groups
- [ ] ALB security group rules
- [ ] ECS tasks security group rules
- [ ] Keycloak ECS security group rules
- [ ] Database security group rules
- [ ] EFS security group rules
- [ ] MCP servers security group rules

### EFS
- [ ] Encryption settings
- [ ] Throughput mode
- [ ] Access points (6 total)
- [ ] POSIX user/group IDs

### Aurora Database
- [ ] Engine version
- [ ] Serverless v2 scaling (min/max ACUs)
- [ ] Encryption settings
- [ ] Backup retention
- [ ] Database name

### RDS Proxy
- [ ] Engine family
- [ ] IAM auth setting
- [ ] Connection pool settings

### ALBs
- [ ] Main ALB listeners (ports 80, 443, 7860, 8888)
- [ ] Keycloak ALB listeners (ports 80, 443)
- [ ] Target group health check paths
- [ ] Target group health check matchers

### IAM Roles
- [ ] Task execution role policies
- [ ] Task role policies
- [ ] Keycloak-specific execution role (SSM access)

---

## Quick Diff Commands

```bash
# Compare Keycloak environment variables
grep -A 50 "keycloak_container_env" terraform/aws-ecs/keycloak-ecs.tf
grep -A 30 "Environment:" cloudformation/aws-ecs/templates/services-stack.yaml | grep -A 30 "KeycloakTaskDefinition"

# Compare CPU/Memory settings
grep -E "cpu|memory" terraform/aws-ecs/keycloak-ecs.tf
grep -E "Cpu:|Memory:" cloudformation/aws-ecs/templates/services-stack.yaml

# Compare health checks
grep -A 10 "healthCheck" terraform/aws-ecs/keycloak-ecs.tf
grep -A 10 "HealthCheck:" cloudformation/aws-ecs/templates/services-stack.yaml
```

---

## Common Pitfalls

1. **Health check commands**: Keycloak uses `exit 0` (no curl available in container)
2. **Secrets source**: Keycloak uses SSM parameters, not Secrets Manager
3. **Proxy settings**: `KC_PROXY=edge` + `KC_PROXY_ADDRESS_FORWARDING=true` (not `KC_PROXY_HEADERS`)
4. **Port mappings**: Keycloak needs both 8080 and 9000 (management)
5. **Auto scaling**: Keycloak has its own cluster, so ResourceId pattern differs
6. **Log group names**: Terraform uses `/ecs/keycloak`, CFN uses `/ecs/${EnvironmentName}-keycloak`

---

## After Sync

1. Update `TERRAFORM-CFN-COMPARISON.md` with current comparison status
2. Run `cfn-lint` on all CloudFormation templates
3. Test deployment in dev environment before production
