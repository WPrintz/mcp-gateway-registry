# Implementation Plan

## Consolidated 5-Template Structure

**Constraint: Maximum 5 CloudFormation templates total (including nested stacks)**
**Target Region: us-west-2**

| Template | Contents | Status |
|----------|----------|--------|
| network-stack.yaml | VPC, Subnets, NAT, Security Groups, VPC Endpoints | ✅ DEPLOYED |
| data-stack.yaml | EFS, Aurora, RDS Proxy, Secrets, SSM, KMS | ✅ DEPLOYED |
| compute-stack.yaml | ECS Clusters, ALBs, DNS, Certificates, ECR, IAM, CodeBuild | ✅ DEPLOYED |
| services-stack.yaml | Task Definitions, Services, Auto Scaling | ✅ DEPLOYED |
| main-stack.yaml | Parent Orchestration | ✅ UPDATED (KeycloakLogLevel param added) |

---

- [x] 1. Set up CloudFormation project structure
  - Create `cloudformation/aws-ecs/` directory structure
  - Create `templates/` subdirectory for nested stacks
  - Create base `README.md` with deployment instructions
  - _Requirements: 13.1, 13.2_

- [x] 2. Create Network Stack (network-stack.yaml)
  - [x] 2.1 Create consolidated network stack with VPC, subnets, gateways, and security groups
    - Define VPC with configurable CIDR block parameter
    - Create 3 public subnets (10.0.48.0/24, 10.0.49.0/24, 10.0.50.0/24)
    - Create 3 private subnets (10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20)
    - Create Internet Gateway and attach to VPC
    - Create 3 NAT Gateways (one per AZ) with Elastic IPs
    - Create route tables and associations
    - Create VPC endpoints for STS and S3
    - Create all security groups (ALB, ECS, Database, EFS, MCP Servers)
    - Export VpcId, subnet IDs, and security group IDs
    - **DEPLOYED as mcp-gateway-network**
    - _Requirements: 1.1-1.6, 12.1-12.5_

- [x] 3. Create Data Stack (data-stack.yaml)
  - [x] 3.1 Create consolidated data stack with EFS, Aurora, Secrets, and KMS
    - Create KMS key for RDS encryption with rotation enabled
    - Create encrypted EFS file system
    - Create mount targets in each private subnet
    - Create 6 access points (servers, models, logs, agents, auth_config, mcpgw_data)
    - Configure POSIX user permissions (UID/GID 1000) for each access point
    - Create Aurora Serverless v2 cluster with encryption
    - Configure serverless scaling (0.5-2 ACUs)
    - Configure automated backups with 7-day retention
    - Create RDS Proxy for connection pooling
    - Create Secrets Manager secrets (database, client secrets, admin password, secret key)
    - Create SSM parameters for Keycloak configuration
    - **DEPLOYED as mcp-gateway-data**
    - _Requirements: 5.1-5.7, 6.1-6.5, 9.1-9.4_

- [x] 4. Create Compute Stack (compute-stack.yaml)
  - [x] 4.1 Create consolidated compute stack with ECS clusters, ALBs, DNS, and IAM
    - Create main MCP Gateway ECS cluster with Container Insights
    - Create Keycloak ECS cluster
    - Configure Fargate and Fargate Spot capacity providers
    - Create Service Discovery private DNS namespace
    - Create Main ALB with listeners (80, 443, 8888, 7860)
    - Create Keycloak ALB with HTTPS and HTTP redirect
    - Create target groups with health checks
    - Create ACM certificates with DNS validation
    - Create Route53 A records for registry and keycloak
    - Create Keycloak ECR repository with lifecycle policy
    - Create ECS Task Execution and Task IAM roles
    - **CREATED - requires Route53 hosted zone for deployment**
    - _Requirements: 2.1-2.4, 4.1-4.6, 7.1-7.4, 8.1-8.4, 14.1-14.4_

- [x] 5. Create Services Stack (services-stack.yaml)
  - [x] 5.1 Create consolidated services stack with all 8 ECS services
    - Create CloudWatch log groups (30-day retention, 7-day for Keycloak)
    - Create Auth Server task definition and service
    - Create Registry task definition and service
    - Create Keycloak task definition and service
    - Create CurrentTime MCP server task definition and service
    - Create MCPGW MCP server task definition and service
    - Create RealServerFakeTools MCP server task definition and service
    - Create Flight Booking Agent task definition and service
    - Create Travel Assistant Agent task definition and service
    - Configure Service Connect for inter-service communication
    - Configure auto scaling targets and policies
    - **DEPLOYED as mcp-gateway-services**
    - _Requirements: 3.1-3.9, 10.1-10.4, 11.1-11.3_

- [x] 6. Create Main Stack (main-stack.yaml)
  - [x] 6.1 Create parent orchestration stack
    - Define all input parameters with defaults matching Terraform
    - Create nested stack references for all 4 component stacks
    - Configure proper DependsOn relationships between stacks
    - Pass parameters and cross-stack references between nested stacks
    - Define comprehensive outputs (URLs, ARNs, IDs)
    - **UPDATED - aligned S3 path convention with Workshop Studio (trailing slash in prefix)**
    - _Requirements: 13.1-13.5_

- [x] 7. Update documentation
  - [x] 7.1 Update README.md with deployment instructions
    - Document individual stack deployment
    - Document main stack deployment via S3
    - Document currently deployed resources
    - Document cleanup procedures
    - _Requirements: 13.2, 13.3_

---

## Remaining Tasks

- [x] 8. Deploy remaining stacks
  - [x] 8.1 Deploy compute-stack (DNS/certs optional - uses ImportValue from network/data stacks)
    - Includes CodeBuild project for container image builds
    - Lambda Custom Resource triggers CodeBuild on stack create/update
    - Builds 7 container images in parallel (~9 min)
    - **DEPLOYED as mcp-gateway-compute**
  - [x] 8.2 Deploy services-stack (uses ImportValue from all previous stacks)
    - **DEPLOYED as mcp-gateway-services**
    - All 8 ECS services running (1/1 each)
  - [x] 8.3 Verify all services are healthy
    - All 4 target groups healthy
    - Main ALB responding at http://mcp-gateway-alb-540864537.us-west-2.elb.amazonaws.com
    - Keycloak ALB responding at http://mcp-gateway-keycloak-alb-1578958238.us-west-2.elb.amazonaws.com

- [x] 9. Add CloudFront for Keycloak HTTPS (no custom domain required)
  - [x] 9.1 Add CloudFront distribution for Keycloak ALB to **compute-stack.yaml**
    - Create CloudFront distribution with Keycloak ALB as origin
    - Use default CloudFront SSL certificate (*.cloudfront.net)
    - Configure origin protocol policy: HTTP only (ALB handles HTTP)
    - Configure cache behavior: CachingDisabled (Keycloak is dynamic)
    - Added custom origin header: `X-Forwarded-Proto: https`
    - Export CloudFront domain name as `${EnvironmentName}-KeycloakCloudFrontDomain`
    - **CloudFront URL: https://d1856vgnusszma.cloudfront.net**
  - [x] 9.2 Update **services-stack.yaml** Keycloak task definition
    - Changed `KC_HOSTNAME_STRICT_HTTPS` to `true` (required for CloudFront setup)
    - Change KC_HOSTNAME to use CloudFront domain (!ImportValue KeycloakCloudFrontDomain)
    - Ensure KC_PROXY=edge is set (already done)
  - [x] 9.3 Update **services-stack.yaml** services that reference Keycloak URL
    - Auth Server: KEYCLOAK_URL, KEYCLOAK_EXTERNAL_URL → CloudFront URL
    - Registry: KEYCLOAK_URL → CloudFront URL
  - [x] 9.4 Deploy updated stacks and verify
    - Update compute-stack (adds CloudFront) ✅
    - Update services-stack (uses CloudFront URL) ✅
    - Test https://d1856vgnusszma.cloudfront.net/realms/master returns 200 ✅
    - OpenID configuration returns HTTPS URLs ✅

- [x] 10. TF-CFN Sync Tooling and Gap Analysis
  - [x] 10.1 Create tf-cfn-sync.py tool with --tf-plan mode for accurate comparison
  - [x] 10.2 Create tf-cfn-mappings.yaml with 109+ explicit TF→CFN mappings
  - [x] 10.3 Add CloudWatch monitoring alarms to services-stack.yaml (7 alarms matching TF)
    - **UNTESTED** - alarms added but not deployed to verify functionality
  - [x] 10.4 Update TF-CFN-GAP-ANALYSIS.md - all gaps now resolved

- [ ] 11. Test main-stack nested deployment
  - [ ] 10.1 Tear down existing individual stacks (reverse order)
    - Delete mcp-gateway-services stack
    - Delete mcp-gateway-compute stack
    - Delete mcp-gateway-data stack
    - Delete mcp-gateway-network stack
  - [ ] 10.2 Upload templates to S3 bucket
    - Create S3 bucket for CloudFormation templates
    - Upload all 4 component templates to S3
  - [ ] 10.3 Deploy main-stack.yaml as nested stack
    - Deploy with required parameters (TemplateS3Bucket, database passwords)
    - Verify all nested stacks create successfully
  - [ ] 10.4 Verify all services healthy after nested deployment
    - All 8 ECS services running
    - All target groups healthy
    - Both ALBs responding

- [ ] 12. Write property-based tests
  - [ ] 11.1 Property 1: Task Definition Fargate Configuration
  - [ ] 11.2 Property 2: Task Definition Logging Configuration
  - [ ] 11.3 Property 3: Task Definition Health Check Configuration
  - [ ] 11.4 Property 4: Target Group Health Check Configuration
  - [ ] 11.5 Property 5: EFS Access Point POSIX Configuration
  - [ ] 11.6 Property 6: Regional Domain Name Pattern
  - [ ] 11.7 Property 7: IAM Policy Least Privilege
  - [ ] 11.8 Property 8: Sensitive Parameter NoEcho
  - [ ] 11.9 Property 9: Log Group Retention Configuration
  - [ ] 11.10 Property 10: ECS Security Group Ingress Restriction
  - [ ] 11.11 Property 11: Parameter Defaults Match Terraform

- [ ] 13. Create test infrastructure
  - [ ] 12.1 Set up pytest test framework with AWS fixtures
  - [ ] 12.2 Create cfn-lint configuration

- [ ] 14. Final Checkpoint - Complete validation
  - Ensure all tests pass, ask the user if questions arise.

---

## Future Enhancements

- [ ] 15. S3 Container Image Import (Workshop Optimization)
  - [ ] 15.1 Add CloudFormation parameters for S3 bucket/prefix
    - Add `ContainerImagesBucket` and `ContainerImagesPrefix` to main-stack.yaml
    - Add same parameters to compute-stack.yaml
    - Pass parameters from main-stack to compute-stack
  - [ ] 15.2 Add CodeBuild environment variables
    - Add `CONTAINER_IMAGES_BUCKET` and `CONTAINER_IMAGES_PREFIX` env vars
  - [ ] 15.3 Update buildspec with S3 import logic
    - Check if bucket is set, import tarballs if so, else build from source
    - Maintain backward compatibility (empty bucket = build from source)
  - [ ] 15.4 Add IAM permissions for S3 read access
  - [ ] 15.5 Create pre-build script for generating tarballs
  - [ ] 15.6 Test both modes (S3 import and source build)
  - **Implementation guide:** `cloudformation/aws-ecs/TODO-S3-IMAGE-IMPORT.md`
  - **Benefits:** Reduces deploy time from ~15 min to ~3 min, eliminates Docker Hub rate limits

- [x] 16. Upstream Sync Strategy
  - [x] 16.1 Merged upstream v1.0.7 into feature/cloudformation-deployment
    - Resolved conflicts in `docker/Dockerfile.mcp-server`, `auth_server/server.py`, `docker-compose.yml`
    - Kept ECR Public base image, accepted upstream cookie security
  - [ ] 16.2 Consider contributing ECR Public Dockerfile change upstream
  - [x] 16.3 Workshop pinned to v1.0.7
  - **Completed:** Merge done locally, not pushed to origin yet

- [x] 17. Sync v1.0.7 Terraform Features to CloudFormation
  - [x] 17.1 Add Embeddings Configuration parameters ✅
    - Added to main-stack.yaml: `EmbeddingsProvider`, `EmbeddingsModelName`, `EmbeddingsModelDimensions`, `EmbeddingsAwsRegion`
    - Added to services-stack.yaml parameters
    - **Note:** `EmbeddingsApiKey` secret NOT added (only needed for litellm provider, workshop uses sentence-transformers)
  - [x] 17.2 Add Session Cookie Security parameters ✅
    - Added to main-stack.yaml: `SessionCookieSecure`, `SessionCookieDomain`
    - Added to services-stack.yaml parameters
  - [x] 17.3 Update Auth Server task definition ✅
    - Added `SESSION_COOKIE_SECURE` environment variable
    - Added `SESSION_COOKIE_DOMAIN` environment variable
  - [x] 17.4 Update Registry task definition ✅
    - Added embeddings env vars: `EMBEDDINGS_PROVIDER`, `EMBEDDINGS_MODEL_NAME`, `EMBEDDINGS_MODEL_DIMENSIONS`, `EMBEDDINGS_AWS_REGION`
    - Added session cookie env vars: `SESSION_COOKIE_SECURE`, `SESSION_COOKIE_DOMAIN`
    - **Note:** `EMBEDDINGS_API_KEY` secret NOT added (only needed for litellm provider)
  - [ ] 17.5 Test deployment with new parameters (not yet tested)
    - Fix `AUTH_SERVER_EXTERNAL_URL` (remove `:8888` port)
  - [ ] 17.5 Test deployment with new parameters
  - **Source:** Terraform changes in v1.0.7 (`modules/mcp-gateway/ecs-services.tf`, `variables.tf`)

---

## Deployed AWS Resources (us-west-2, Account 704390743772)

### Stack: mcp-gateway-network
- VPC: `vpc-04900b8315707977b`
- Public Subnets: `subnet-044c234fcf392115e`, `subnet-0370c083e05990200`, `subnet-0a771b97005f799ee`
- Private Subnets: `subnet-0735428ee0dc664e2`, `subnet-0cc9ccf88b4b23876`, `subnet-03595bec2f9489584`
- Security Groups:
  - Main ALB: `sg-084a0f5cd6171750e`
  - Keycloak ALB: `sg-02d6951014263e980`
  - ECS Tasks: `sg-0db1f3db0858d21c5`
  - Keycloak ECS: `sg-08da55df90e59d9ea`
  - Database: `sg-0a03d7ea74ab53254`
  - EFS: `sg-03b82c1398b75f7cb`
  - MCP Servers: `sg-0b404804a88590f95`

### Stack: mcp-gateway-data
- EFS: `fs-0a3a37bef4e84ee90`
- Aurora Cluster Endpoint: `mcp-gateway-keycloak.cluster-c5dv9t0nitzc.us-west-2.rds.amazonaws.com`
- RDS Proxy Endpoint: `mcp-gateway-keycloak-proxy.proxy-c5dv9t0nitzc.us-west-2.rds.amazonaws.com`

### Stack: mcp-gateway-compute
- Main ECS Cluster: `mcp-gateway-ecs-cluster`
- Keycloak ECS Cluster: `mcp-gateway-keycloak-cluster`
- Main ALB: `mcp-gateway-alb-540864537.us-west-2.elb.amazonaws.com`
- Keycloak ALB: `mcp-gateway-keycloak-alb-1578958238.us-west-2.elb.amazonaws.com`
- ECR Repositories: 8 repos (registry, auth-server, currenttime, mcpgw, realserverfaketools, flight-booking-agent, travel-assistant-agent, keycloak)
- CodeBuild Project: `mcp-gateway-container-build`

### Stack: mcp-gateway-services
- ECS Services (all 1/1 running):
  - `mcp-gateway-keycloak` (Keycloak cluster)
  - `mcp-gateway-auth-server`
  - `mcp-gateway-registry`
  - `mcp-gateway-mcpgw`
  - `mcp-gateway-currenttime`
  - `mcp-gateway-realserverfaketools`
  - `mcp-gateway-flight-booking-agent`
  - `mcp-gateway-travel-assistant-agent`
- Target Groups (all healthy):
  - `mcp-gateway-auth-tg` (10.0.15.0)
  - `mcp-gateway-gradio-tg` (10.0.7.209)
  - `mcp-gateway-registry-tg` (10.0.7.209)
  - `mcp-gateway-keycloak-tg` (10.0.28.69)
