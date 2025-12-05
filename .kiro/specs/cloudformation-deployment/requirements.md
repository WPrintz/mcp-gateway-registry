# Requirements Document

## Introduction

This specification defines the requirements for converting the existing Terraform-based AWS ECS Fargate infrastructure to AWS CloudFormation. The MCP Gateway Registry is a production-grade, multi-region infrastructure that includes ECS Fargate services, Aurora Serverless database, Keycloak authentication, and supporting AWS services. The CloudFormation implementation will maintain feature parity with the existing Terraform deployment while following AWS CloudFormation best practices.

## Glossary

- **MCP Gateway Registry**: The core application providing MCP server registry and discovery services
- **Auth Server**: OAuth2/OIDC authentication service that integrates with Keycloak
- **Keycloak**: Identity and access management system providing SSO and user management
- **ECS Fargate**: AWS serverless container orchestration service
- **Aurora Serverless v2**: Auto-scaling relational database service
- **EFS**: Elastic File System for shared persistent storage
- **ALB**: Application Load Balancer for HTTP/HTTPS traffic distribution
- **Service Connect**: ECS feature for service-to-service communication
- **ACM**: AWS Certificate Manager for SSL/TLS certificates
- **Nested Stack**: CloudFormation template referenced by a parent template

## Requirements

### Requirement 1: VPC and Network Infrastructure

**User Story:** As a platform operator, I want the CloudFormation templates to provision a complete VPC with proper network segmentation, so that the MCP Gateway services run in a secure, highly available network environment.

#### Acceptance Criteria

1. WHEN the VPC stack is deployed THEN the CloudFormation_Template SHALL create a VPC with the specified CIDR block (default 10.0.0.0/16)
2. WHEN the VPC stack is deployed THEN the CloudFormation_Template SHALL create public and private subnets across 3 availability zones
3. WHEN the VPC stack is deployed THEN the CloudFormation_Template SHALL create one NAT Gateway per availability zone for high availability
4. WHEN the VPC stack is deployed THEN the CloudFormation_Template SHALL create VPC endpoints for STS (Interface) and S3 (Gateway) services
5. WHEN the VPC stack is deployed THEN the CloudFormation_Template SHALL enable DNS hostnames and DNS support on the VPC
6. WHEN the VPC stack is deployed THEN the CloudFormation_Template SHALL create appropriate route tables for public and private subnets

### Requirement 2: ECS Cluster Configuration

**User Story:** As a platform operator, I want CloudFormation to provision ECS clusters with Fargate capacity providers, so that containerized services can run without managing EC2 instances.

#### Acceptance Criteria

1. WHEN the ECS cluster stack is deployed THEN the CloudFormation_Template SHALL create two ECS clusters (main MCP Gateway cluster and Keycloak cluster)
2. WHEN the ECS clusters are created THEN the CloudFormation_Template SHALL configure Fargate and Fargate Spot capacity providers
3. WHEN the ECS clusters are created THEN the CloudFormation_Template SHALL enable Container Insights for monitoring
4. WHEN the ECS clusters are created THEN the CloudFormation_Template SHALL configure execute command logging to CloudWatch

### Requirement 3: ECS Task Definitions and Services

**User Story:** As a platform operator, I want CloudFormation to define all ECS task definitions and services, so that the MCP Gateway components run as containerized workloads.

#### Acceptance Criteria

1. WHEN the services stack is deployed THEN the CloudFormation_Template SHALL create task definitions for all 8 services (Registry, Auth Server, Keycloak, CurrentTime, MCPGW, RealServerFakeTools, Flight Booking Agent, Travel Assistant Agent)
2. WHEN task definitions are created THEN the CloudFormation_Template SHALL configure Fargate launch type with awsvpc network mode
3. WHEN task definitions are created THEN the CloudFormation_Template SHALL configure appropriate CPU and memory allocations per service
4. WHEN task definitions are created THEN the CloudFormation_Template SHALL configure environment variables and secrets references
5. WHEN task definitions are created THEN the CloudFormation_Template SHALL configure EFS volume mounts where required
6. WHEN task definitions are created THEN the CloudFormation_Template SHALL configure CloudWatch logging with appropriate log groups
7. WHEN task definitions are created THEN the CloudFormation_Template SHALL configure health checks for each container
8. WHEN ECS services are created THEN the CloudFormation_Template SHALL configure Service Connect for inter-service communication
9. WHEN ECS services are created THEN the CloudFormation_Template SHALL configure load balancer target group attachments where applicable

### Requirement 4: Application Load Balancers

**User Story:** As a platform operator, I want CloudFormation to provision Application Load Balancers with proper routing, so that external traffic reaches the appropriate services securely.

#### Acceptance Criteria

1. WHEN the ALB stack is deployed THEN the CloudFormation_Template SHALL create two Application Load Balancers (Main ALB and Keycloak ALB)
2. WHEN the Main ALB is created THEN the CloudFormation_Template SHALL configure listeners for HTTP (80), HTTPS (443), Auth (8888), and Gradio (7860) ports
3. WHEN the Keycloak ALB is created THEN the CloudFormation_Template SHALL configure listeners for HTTP (80) and HTTPS (443) with redirect
4. WHEN ALBs are created THEN the CloudFormation_Template SHALL configure target groups with health checks for each backend service
5. WHEN HTTPS listeners are created THEN the CloudFormation_Template SHALL reference ACM certificate ARNs for SSL termination
6. WHEN ALBs are created THEN the CloudFormation_Template SHALL configure security groups with appropriate ingress rules based on allowed CIDR blocks

### Requirement 5: Aurora Serverless Database

**User Story:** As a platform operator, I want CloudFormation to provision Aurora Serverless v2 for Keycloak, so that the identity management system has a scalable, managed database.

#### Acceptance Criteria

1. WHEN the database stack is deployed THEN the CloudFormation_Template SHALL create an Aurora MySQL Serverless v2 cluster
2. WHEN the Aurora cluster is created THEN the CloudFormation_Template SHALL configure serverless scaling with min/max ACU settings (default 0.5-2 ACUs)
3. WHEN the Aurora cluster is created THEN the CloudFormation_Template SHALL configure encryption at rest using KMS
4. WHEN the Aurora cluster is created THEN the CloudFormation_Template SHALL create a DB subnet group using private subnets
5. WHEN the Aurora cluster is created THEN the CloudFormation_Template SHALL configure automated backups with 7-day retention
6. WHEN the database stack is deployed THEN the CloudFormation_Template SHALL create an RDS Proxy for connection pooling
7. WHEN the database stack is deployed THEN the CloudFormation_Template SHALL store credentials in Secrets Manager

### Requirement 6: Elastic File System Storage

**User Story:** As a platform operator, I want CloudFormation to provision EFS with access points, so that ECS tasks have shared persistent storage.

#### Acceptance Criteria

1. WHEN the storage stack is deployed THEN the CloudFormation_Template SHALL create an encrypted EFS file system
2. WHEN the EFS is created THEN the CloudFormation_Template SHALL create mount targets in each private subnet
3. WHEN the EFS is created THEN the CloudFormation_Template SHALL create 6 access points (servers, models, logs, agents, auth_config, mcpgw_data)
4. WHEN access points are created THEN the CloudFormation_Template SHALL configure POSIX user permissions (UID/GID 1000)
5. WHEN the EFS is created THEN the CloudFormation_Template SHALL configure security groups allowing NFS traffic from the VPC

### Requirement 7: DNS and SSL Certificates

**User Story:** As a platform operator, I want CloudFormation to manage DNS records and SSL certificates, so that services are accessible via custom domains with HTTPS.

#### Acceptance Criteria

1. WHEN the DNS stack is deployed THEN the CloudFormation_Template SHALL create ACM certificates for Keycloak and Registry domains
2. WHEN ACM certificates are created THEN the CloudFormation_Template SHALL create Route53 DNS validation records
3. WHEN the DNS stack is deployed THEN the CloudFormation_Template SHALL create Route53 A records pointing to the respective ALBs
4. WHEN regional domains are enabled THEN the CloudFormation_Template SHALL construct domain names using the pattern {service}.{region}.{base_domain}

### Requirement 8: IAM Roles and Policies

**User Story:** As a platform operator, I want CloudFormation to create least-privilege IAM roles, so that ECS tasks have only the permissions they need.

#### Acceptance Criteria

1. WHEN the IAM resources are created THEN the CloudFormation_Template SHALL create task execution roles with permissions for ECR, CloudWatch Logs, Secrets Manager, and SSM Parameter Store
2. WHEN the IAM resources are created THEN the CloudFormation_Template SHALL create task roles with permissions for SSM Session Manager (ECS Exec)
3. WHEN the IAM resources are created THEN the CloudFormation_Template SHALL create an RDS Proxy IAM role with Secrets Manager access
4. WHEN IAM policies are created THEN the CloudFormation_Template SHALL follow least-privilege principles with resource-specific ARNs where possible

### Requirement 9: Secrets and Parameter Management

**User Story:** As a platform operator, I want CloudFormation to manage secrets and parameters securely, so that sensitive credentials are not exposed in templates.

#### Acceptance Criteria

1. WHEN the secrets stack is deployed THEN the CloudFormation_Template SHALL create Secrets Manager secrets for database credentials, admin passwords, and client secrets
2. WHEN the secrets stack is deployed THEN the CloudFormation_Template SHALL create SSM Parameter Store SecureString parameters for Keycloak configuration
3. WHEN secrets are created THEN the CloudFormation_Template SHALL accept initial values as template parameters marked as NoEcho
4. WHEN KMS is required THEN the CloudFormation_Template SHALL create a KMS key for RDS encryption with key rotation enabled

### Requirement 10: Auto Scaling Configuration

**User Story:** As a platform operator, I want CloudFormation to configure auto scaling for ECS services, so that capacity adjusts based on demand.

#### Acceptance Criteria

1. WHEN auto scaling is enabled THEN the CloudFormation_Template SHALL create Application Auto Scaling targets for ECS services
2. WHEN auto scaling targets are created THEN the CloudFormation_Template SHALL configure target tracking policies for CPU utilization (target 70%)
3. WHEN auto scaling targets are created THEN the CloudFormation_Template SHALL configure target tracking policies for memory utilization (target 80%)
4. WHEN auto scaling is configured THEN the CloudFormation_Template SHALL set min capacity of 2 and max capacity of 4 for main services

### Requirement 11: CloudWatch Monitoring

**User Story:** As a platform operator, I want CloudFormation to create CloudWatch resources, so that I can monitor the health and performance of all services.

#### Acceptance Criteria

1. WHEN the monitoring resources are created THEN the CloudFormation_Template SHALL create CloudWatch Log Groups for each ECS service with 30-day retention
2. WHEN Container Insights is enabled THEN the CloudFormation_Template SHALL configure the ECS cluster setting for containerInsights
3. WHEN the Keycloak log group is created THEN the CloudFormation_Template SHALL configure 7-day retention as specified in the Terraform configuration

### Requirement 12: Security Groups

**User Story:** As a platform operator, I want CloudFormation to create security groups with proper rules, so that network traffic is restricted to only what is necessary.

#### Acceptance Criteria

1. WHEN security groups are created THEN the CloudFormation_Template SHALL create separate security groups for ALBs, ECS tasks, databases, EFS, and VPC endpoints
2. WHEN ALB security groups are created THEN the CloudFormation_Template SHALL allow ingress from specified CIDR blocks on required ports
3. WHEN ECS task security groups are created THEN the CloudFormation_Template SHALL allow ingress only from the associated ALB security group
4. WHEN database security groups are created THEN the CloudFormation_Template SHALL allow ingress only from ECS task security groups on port 3306
5. WHEN inter-service communication is required THEN the CloudFormation_Template SHALL create security group rules allowing traffic between dependent services

### Requirement 13: Template Organization and Parameters

**User Story:** As a platform operator, I want the CloudFormation templates to be well-organized with clear parameters, so that deployments are configurable and maintainable.

#### Acceptance Criteria

1. WHEN templates are organized THEN the CloudFormation_Template SHALL use nested stacks for logical separation of resources
2. WHEN parameters are defined THEN the CloudFormation_Template SHALL include parameters for region, domain configuration, CIDR blocks, and credentials
3. WHEN parameters are defined THEN the CloudFormation_Template SHALL provide sensible defaults matching the Terraform configuration
4. WHEN outputs are defined THEN the CloudFormation_Template SHALL export key resource identifiers (VPC ID, subnet IDs, cluster ARNs, ALB DNS names, service URLs)
5. WHEN cross-stack references are needed THEN the CloudFormation_Template SHALL use Fn::ImportValue with exported outputs

### Requirement 14: ECR Repository Configuration

**User Story:** As a platform operator, I want CloudFormation to create ECR repositories with lifecycle policies, so that container images are stored and managed properly.

#### Acceptance Criteria

1. WHEN the ECR stack is deployed THEN the CloudFormation_Template SHALL create an ECR repository for Keycloak images
2. WHEN ECR repositories are created THEN the CloudFormation_Template SHALL enable image scanning on push
3. WHEN ECR repositories are created THEN the CloudFormation_Template SHALL configure lifecycle policies to expire old images
4. WHEN ECR repositories are created THEN the CloudFormation_Template SHALL configure repository policies allowing ECS task pulls
