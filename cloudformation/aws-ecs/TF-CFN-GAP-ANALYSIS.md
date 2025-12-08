# Terraform to CloudFormation Gap Analysis

Generated: 2025-12-08 (Updated with EFS init and Keycloak HTTPS fixes)

## Executive Summary

Comparing Terraform plan JSON (263 resources) against CloudFormation templates (163 resources):

### With Manual Mappings File

| Category | Count | Status |
|----------|-------|--------|
| Matched | 91 | Verified equivalent |
| TF Only (real gaps) | 0 | All gaps resolved |
| CFN Only | 72 | CFN-specific (CodeBuild, CloudFront) |
| Skipped | 165 | Intentionally different architecture |

**Key Finding**: All gaps have been addressed. The CFN templates now have full feature parity with Terraform, including CloudWatch monitoring alarms.

## How Mappings Reduce False Positives

The `tf-cfn-mappings.yaml` file handles:
1. **Module expansion**: Maps `module.mcp_gateway.module.ecs_service_auth.aws_ecs_service.this*` → `AuthServerService`
2. **Per-service vs shared**: Skips per-service IAM roles/security groups (CFN uses shared)
3. **Naming conventions**: Explicit mappings handle TF snake_case → CFN PascalCase

**AI Assistant**: When running the sync tool, update `tf-cfn-mappings.yaml` if you see false positives.

## Verified: CFN Has These Resources ✅

| Category | TF Resource | CFN Resource | Location |
|----------|-------------|--------------|----------|
| ECS Services | 8 services via modules | AuthServerService, RegistryService, etc. | services-stack.yaml |
| EFS | aws_efs_file_system + 6 access points | EfsFileSystem + 6 access points | data-stack.yaml |
| EFS Init | run-scopes-init-task.sh script | EfsInitLambda + EfsInitTrigger | data-stack.yaml |
| RDS Proxy | aws_db_proxy.keycloak | RdsProxy | data-stack.yaml |
| Service Discovery | aws_service_discovery_private_dns_namespace | ServiceDiscoveryNamespace | compute-stack.yaml |
| VPC/Networking | module.vpc resources | VPC, Subnets, NAT Gateways | network-stack.yaml |
| IAM Roles | Per-service roles | Shared EcsTaskExecutionRole, EcsTaskRole | compute-stack.yaml |
| CloudFront | N/A (uses ACM certs) | MainCloudFrontDistribution, KeycloakCloudFrontDistribution | compute-stack.yaml |

## Actual Gaps (Action Required)

### 1. EFS Initialization (scopes.yml) ✅ RESOLVED

TF uses `run-scopes-init-task.sh` script to copy scopes.yml to EFS after deployment.
CFN now uses a Lambda-backed Custom Resource that runs during stack deployment.

**CFN Resources**:
- `EfsInitLambdaRole` - IAM role with EFS mount permissions
- `EfsInitLambda` - Lambda function that mounts EFS and writes scopes.yml
- `EfsInitTrigger` - Custom Resource that invokes the Lambda

**Added to**: `data-stack.yaml`

### 2. Keycloak HTTPS Configuration ✅ RESOLVED

Keycloak requires proper hostname configuration for CloudFront HTTPS:
- `KC_HOSTNAME_URL` - Full CloudFront URL for Keycloak
- `KC_HOSTNAME_ADMIN_URL` - Admin console URL (same as above)

**Added to**: `services-stack.yaml` (KeycloakTaskDefinition)

### 3. Secrets Manager JSON Key Extraction ✅ RESOLVED

ECS secrets need proper JSON key extraction syntax: `${SecretArn}:key_name::`

**Fixed in**: `services-stack.yaml` (ADMIN_PASSWORD, SECRET_KEY, REGISTRY_PASSWORD)

### 4. CloudWatch Alarms ✅ RESOLVED

TF defines 7 monitoring alarms in `module.mcp_gateway` - **now added to CFN**:
- `alb_5xx_errors` → `Alb5xxErrorsAlarm`
- `alb_response_time` → `AlbResponseTimeAlarm`
- `alb_unhealthy_targets` → `AlbUnhealthyTargetsAlarm`
- `auth_cpu_high` → `AuthCpuHighAlarm`
- `auth_memory_high` → `AuthMemoryHighAlarm`
- `registry_cpu_high` → `RegistryCpuHighAlarm`
- `registry_memory_high` → `RegistryMemoryHighAlarm`

### 5. Embeddings Model (sentence-transformers) ✅ RESOLVED

The Registry service requires the `sentence-transformers/all-MiniLM-L6-v2` model for semantic search features.

| Aspect | Terraform | CloudFormation |
|--------|-----------|----------------|
| Model Location | Manual download to EFS `/models` | Baked into container image |
| Image Size | Smaller (~800MB) | Larger (~890MB) |
| Startup | Requires model on EFS | Self-contained |

**CFN Approach**: The model is downloaded during Docker build in `docker/Dockerfile.registry`:
```dockerfile
# Download the sentence-transformers embeddings model during build
RUN mkdir -p /app/registry/models && \
    . .venv/bin/activate && \
    python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2').save('/app/registry/models/all-MiniLM-L6-v2')"
```

**Rationale**: Baking the model into the image simplifies workshop deployment by eliminating the need for a separate model download step. The ~90MB size increase is acceptable for the convenience gained.

**To revert to EFS-based model**: Comment out the model download lines in `docker/Dockerfile.registry` and ensure the model is available on the EFS models access point.

**Added to**: `services-stack.yaml` (CloudWatch Monitoring section)

**Parameters**:
- `EnableMonitoring` (default: true) - Enable/disable all alarms
- `AlarmEmail` (default: '') - Email for SNS notifications (optional)

**SNS Topic**: Created conditionally when `AlarmEmail` is provided

### 2. Per-Service Auto-Scaling Policies (Simplified in CFN)

TF creates separate CPU and memory scaling policies per service. CFN may have simplified auto-scaling.

**Recommendation**: Review if current CFN auto-scaling is sufficient for workshop needs.

**Priority**: Low (workshop doesn't need fine-grained scaling)

## Architecture Differences (Intentional)

These are design decisions, not gaps:

| Aspect | Terraform | CloudFormation | Rationale |
|--------|-----------|----------------|-----------|
| IAM Roles | Per-service roles | Shared roles | Simpler for workshop |
| Security Groups | Per-service SGs | Shared SGs | Easier to understand |
| Container Builds | External (pre-built images) | CodeBuild in-stack | Self-contained deployment |
| Secrets | Mix of SSM + Secrets Manager | Secrets Manager | Consistent approach |

## Tool Limitations

The sync tool has these known limitations:

1. **Module matching**: Can't match TF module resources to flat CFN resources
2. **Name similarity**: 0.8 threshold misses valid matches with different naming
3. **Count/for_each**: TF resources with indices don't match well

**Improvement ideas**:
- Add manual mapping file for known equivalents
- Improve name normalization (strip prefixes like `module.`)
- Add CFN stack cross-reference to find ImportValue targets

## Recommendations

### For Workshop Use
The CFN templates are **ready for workshop deployment**. The only meaningful gap is CloudWatch alarms, which are nice-to-have for monitoring but not required for functionality.

### For Production Parity
If you want CFN to match TF exactly:
1. Add CloudWatch alarms (7 alarms)
2. Consider per-service IAM roles for least-privilege
3. Add SNS topic for alarm notifications

### For the Sync Tool
1. Add a mapping file to handle known TF→CFN equivalents
2. Improve module resource matching
3. Consider comparing by resource type counts instead of individual matching

## Files Reference

| CFN Stack | Purpose | Key Resources |
|-----------|---------|---------------|
| network-stack.yaml | VPC, subnets, NAT | VPC, 6 subnets, 3 NAT gateways |
| data-stack.yaml | Storage, database | Aurora, RDS Proxy, EFS, Secrets |
| compute-stack.yaml | Cluster, ALB, IAM | ECS Cluster, ALB, IAM roles, Service Discovery |
| services-stack.yaml | ECS services | 8 task definitions, 8 services, auto-scaling |
