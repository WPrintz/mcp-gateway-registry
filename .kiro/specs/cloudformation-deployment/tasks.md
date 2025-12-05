# Implementation Plan

- [x] 1. Set up CloudFormation project structure
  - Create `cloudformation/aws-ecs/` directory structure
  - Create `templates/` subdirectory for nested stacks
  - Create `scripts/` subdirectory for deployment scripts
  - Create `tests/` subdirectory for validation tests
  - Create base `README.md` with deployment instructions
  - _Requirements: 13.1, 13.2_

- [-] 2. Create VPC and networking stack
  - [ ] 2.1 Create vpc-stack.yaml with VPC, subnets, and gateways
    - Define VPC with configurable CIDR block parameter
    - Create 3 public subnets across AZs with proper CIDR allocation
    - Create 3 private subnets across AZs with proper CIDR allocation
    - Create Internet Gateway and attach to VPC
    - Create 3 NAT Gateways (one per AZ) with Elastic IPs
    - Create route tables and associations
    - Create VPC endpoints for STS and S3
    - Export VpcId, subnet IDs, and route table IDs
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [ ] 2.2 Write property test for VPC configuration
    - **Property 11: Parameter Defaults Match Terraform**
    - **Validates: Requirements 13.3**

- [ ] 3. Create security groups stack
  - [ ] 3.1 Create security-groups-stack.yaml
    - Define Main ALB security group with configurable ingress CIDR
    - Define Keycloak ALB security group
    - Define ECS tasks security groups (Registry, Auth, MCP servers)
    - Define Keycloak ECS security group
    - Define Database security group (MySQL port 3306)
    - Define EFS security group (NFS port 2049)
    - Define VPC endpoints security group
    - Configure inter-service security group rules
    - Export all security group IDs
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

  - [ ] 3.2 Write property test for ECS security group ingress
    - **Property 10: ECS Security Group Ingress Restriction**
    - **Validates: Requirements 12.3**

- [ ] 4. Create EFS storage stack
  - [ ] 4.1 Create efs-stack.yaml
    - Create encrypted EFS file system
    - Create mount targets in each private subnet
    - Create 6 access points (servers, models, logs, agents, auth_config, mcpgw_data)
    - Configure POSIX user permissions (UID/GID 1000) for each access point
    - Export FileSystemId and AccessPoint IDs
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ] 4.2 Write property test for EFS access point POSIX configuration
    - **Property 5: EFS Access Point POSIX Configuration**
    - **Validates: Requirements 6.4**

- [ ] 5. Create secrets and parameters stack
  - [ ] 5.1 Create secrets-stack.yaml
    - Create KMS key for encryption with rotation enabled
    - Create Secrets Manager secret for database credentials
    - Create Secrets Manager secret for Keycloak client secrets
    - Create Secrets Manager secret for admin password
    - Create Secrets Manager secret for application secret key
    - Create SSM parameters for Keycloak configuration
    - Configure NoEcho for all sensitive input parameters
    - Export secret ARNs for task definition references
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [ ] 5.2 Write property test for NoEcho parameter configuration
    - **Property 8: Sensitive Parameter NoEcho**
    - **Validates: Requirements 9.3**

- [ ] 6. Create IAM roles stack
  - [ ] 6.1 Create iam-stack.yaml
    - Create ECS Task Execution Role with ECR, CloudWatch, Secrets Manager, SSM access
    - Create ECS Task Role with SSM Session Manager permissions
    - Create Keycloak-specific task execution and task roles
    - Create RDS Proxy IAM role with Secrets Manager access
    - Use resource-specific ARNs in policies where possible
    - Export all role ARNs
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [ ] 6.2 Write property test for IAM least privilege
    - **Property 7: IAM Policy Least Privilege**
    - **Validates: Requirements 8.4**

- [ ] 7. Create database stack
  - [ ] 7.1 Create database-stack.yaml
    - Create DB subnet group using private subnets
    - Create RDS cluster parameter group for Aurora MySQL 8.0
    - Create Aurora Serverless v2 cluster with encryption
    - Configure serverless scaling (0.5-2 ACUs)
    - Configure automated backups with 7-day retention
    - Create Aurora cluster instance (db.serverless)
    - Create RDS Proxy for connection pooling
    - Create RDS Proxy target group
    - Export cluster endpoint and proxy endpoint
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [ ] 8. Create ECR repository stack
  - [ ] 8.1 Create ecr-stack.yaml
    - Create Keycloak ECR repository
    - Enable image scanning on push
    - Configure lifecycle policy to expire old images
    - Configure repository policy for ECS task pulls
    - Export repository URI
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [ ] 9. Create ECS cluster stack
  - [ ] 9.1 Create ecs-cluster-stack.yaml
    - Create main MCP Gateway ECS cluster
    - Create Keycloak ECS cluster
    - Configure Fargate and Fargate Spot capacity providers
    - Enable Container Insights
    - Configure execute command logging
    - Create Service Discovery private DNS namespace
    - Create CloudWatch log groups for cluster logging
    - Export cluster ARNs, names, and namespace ARN
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 10. Checkpoint - Validate foundation stacks
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Create ALB stack
  - [ ] 11.1 Create alb-stack.yaml
    - Create Main ALB in public subnets
    - Create Keycloak ALB in public subnets
    - Create target groups for registry (port 7860), auth (port 8888), gradio (port 7860), keycloak (port 8080)
    - Configure health checks for each target group
    - Create HTTP listener (port 80) for Main ALB
    - Create HTTPS listener (port 443) for Main ALB with certificate
    - Create Auth listener (port 8888) for Main ALB
    - Create Gradio listener (port 7860) for Main ALB
    - Create HTTP to HTTPS redirect for Keycloak ALB
    - Create HTTPS listener for Keycloak ALB
    - Export ALB DNS names, ARNs, zone IDs, and target group ARNs
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [ ] 11.2 Write property test for target group health checks
    - **Property 4: Target Group Health Check Configuration**
    - **Validates: Requirements 4.4**

- [ ] 12. Create DNS and certificates stack
  - [ ] 12.1 Create dns-stack.yaml
    - Create ACM certificate for Registry domain with DNS validation
    - Create ACM certificate for Keycloak domain with DNS validation
    - Create Route53 validation records for certificates
    - Create Route53 A record for Registry pointing to Main ALB
    - Create Route53 A record for Keycloak pointing to Keycloak ALB
    - Implement regional domain pattern ({service}.{region}.{base_domain})
    - Export certificate ARNs and domain names
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [ ] 12.2 Write property test for regional domain pattern
    - **Property 6: Regional Domain Name Pattern**
    - **Validates: Requirements 7.4**

- [ ] 13. Create ECS services stack - Core services
  - [ ] 13.1 Create ecs-services-stack.yaml with Registry and Auth Server
    - Create CloudWatch log groups with 30-day retention
    - Create Registry task definition (Fargate, awsvpc, CPU/memory, EFS volumes, secrets, health check)
    - Create Auth Server task definition (Fargate, awsvpc, CPU/memory, EFS volumes, secrets, health check)
    - Create Registry ECS service with Service Connect and ALB attachment
    - Create Auth Server ECS service with Service Connect and ALB attachment
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9_

  - [ ] 13.2 Write property tests for task definition configuration
    - **Property 1: Task Definition Fargate Configuration**
    - **Property 2: Task Definition Logging Configuration**
    - **Property 3: Task Definition Health Check Configuration**
    - **Validates: Requirements 3.2, 3.6, 3.7**

- [ ] 14. Create ECS services stack - Keycloak
  - [ ] 14.1 Add Keycloak task definition and service to ecs-services-stack.yaml
    - Create Keycloak CloudWatch log group with 7-day retention
    - Create Keycloak task definition with database connection secrets
    - Create Keycloak ECS service with ALB attachment
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 3.7, 3.9, 11.3_

  - [ ] 14.2 Write property test for log group retention
    - **Property 9: Log Group Retention Configuration**
    - **Validates: Requirements 11.1**

- [ ] 15. Create ECS services stack - MCP Servers
  - [ ] 15.1 Add MCP server task definitions and services
    - Create CurrentTime MCP server task definition and service (port 8000)
    - Create MCPGW MCP server task definition and service (port 8003)
    - Create RealServerFakeTools MCP server task definition and service (port 8002)
    - Configure Service Connect for inter-service communication
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 3.7, 3.8_

- [ ] 16. Create ECS services stack - A2A Agents
  - [ ] 16.1 Add A2A agent task definitions and services
    - Create Flight Booking Agent task definition and service (port 9000)
    - Create Travel Assistant Agent task definition and service (port 9001)
    - Configure Service Connect for inter-service communication
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 3.7, 3.8_

- [ ] 17. Checkpoint - Validate ECS services
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 18. Create auto scaling stack
  - [ ] 18.1 Create autoscaling-stack.yaml
    - Create Application Auto Scaling targets for all ECS services
    - Create CPU target tracking scaling policies (target 70%)
    - Create Memory target tracking scaling policies (target 80%)
    - Configure min capacity 2, max capacity 4 for main services
    - Configure min capacity 1, max capacity 4 for Keycloak
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 19. Create main parent stack
  - [ ] 19.1 Create main-stack.yaml
    - Define all input parameters with defaults matching Terraform
    - Create nested stack references for all component stacks
    - Configure proper DependsOn relationships between stacks
    - Pass parameters and cross-stack references between nested stacks
    - Define comprehensive outputs (URLs, ARNs, IDs)
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

- [ ] 20. Create deployment scripts and documentation
  - [ ] 20.1 Create deployment helper scripts
    - Create `deploy.sh` script for stack deployment
    - Create `delete.sh` script for stack cleanup
    - Create `validate.sh` script for template validation with cfn-lint
    - Create `parameters.json.example` template file
    - _Requirements: 13.2_

  - [ ] 20.2 Create comprehensive README.md
    - Document prerequisites (AWS CLI, cfn-lint)
    - Document parameter configuration
    - Document deployment steps (two-stage for certificates)
    - Document post-deployment steps
    - Document troubleshooting guide
    - _Requirements: 13.2, 13.3_

- [ ] 21. Create test infrastructure
  - [ ] 21.1 Set up pytest test framework
    - Create `tests/conftest.py` with AWS fixtures
    - Create `tests/test_properties.py` for property-based tests
    - Configure hypothesis for property testing
    - _Requirements: 3.2, 3.6, 3.7, 4.4, 6.4, 7.4, 8.4, 9.3, 11.1, 12.3, 13.3_

  - [ ] 21.2 Create cfn-lint configuration
    - Create `.cfnlintrc` configuration file
    - Configure rules and exceptions
    - Add lint validation to CI workflow

- [ ] 22. Final Checkpoint - Complete validation
  - Ensure all tests pass, ask the user if questions arise.
