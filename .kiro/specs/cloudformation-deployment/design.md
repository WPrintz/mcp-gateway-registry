# Design Document: CloudFormation Deployment for MCP Gateway Registry

## Overview

This design document describes the architecture and implementation approach for converting the existing Terraform-based MCP Gateway Registry infrastructure to AWS CloudFormation. The solution uses nested CloudFormation stacks to organize resources logically, maintain separation of concerns, and enable independent updates to different infrastructure components.

The CloudFormation implementation will deploy the same infrastructure as the Terraform version: a production-grade ECS Fargate environment with Aurora Serverless database, Keycloak authentication, multiple MCP servers, and supporting AWS services.

## Architecture

### Stack Hierarchy

**Constraint: Maximum 5 CloudFormation templates total (including nested stacks)**
**Target Region: us-west-2**

```
┌─────────────────────────────────────────────────────────────────┐
│                     main-stack.yaml                              │
│                   (Parent/Root Stack)                            │
├─────────────────────────────────────────────────────────────────┤
│  Parameters: Region, Domain, Credentials, CIDR blocks           │
│  Nested Stacks (4 total):                                       │
│    ├── network-stack.yaml     (VPC, Subnets, NAT, SGs, VPC EP) │
│    ├── data-stack.yaml        (EFS, Aurora, RDS Proxy, Secrets)│
│    ├── compute-stack.yaml     (ECS Clusters, ALBs, DNS, ECR)   │
│    └── services-stack.yaml    (Task Defs, Services, AutoScale) │
└─────────────────────────────────────────────────────────────────┘
```

### Consolidated Stack Contents

| Stack | Resources Included |
|-------|-------------------|
| **main-stack.yaml** | Parent orchestration, parameters, cross-stack references |
| **network-stack.yaml** | VPC, subnets (public/private), NAT gateways, Internet gateway, route tables, all security groups, VPC endpoints |
| **data-stack.yaml** | EFS file system, EFS access points, Aurora Serverless cluster, RDS Proxy, Secrets Manager secrets, SSM parameters, KMS keys |
| **compute-stack.yaml** | ECS clusters, ALBs, target groups, listeners, ACM certificates, Route53 records, ECR repositories, IAM roles |
| **services-stack.yaml** | All 8 ECS task definitions, all 8 ECS services, auto scaling targets and policies, CloudWatch log groups |

### Network Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VPC (10.0.0.0/16)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │  Public Subnet   │  │  Public Subnet   │  │  Public Subnet   │          │
│  │    AZ-1 (a)      │  │    AZ-2 (b)      │  │    AZ-3 (c)      │          │
│  │  10.0.48.0/24    │  │  10.0.49.0/24    │  │  10.0.50.0/24    │          │
│  │                  │  │                  │  │                  │          │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │          │
│  │  │ NAT GW    │  │  │  │ NAT GW    │  │  │  │ NAT GW    │  │          │
│  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │          │
│  │                  │  │                  │  │                  │          │
│  │  ┌─────────────────────────────────────────────────────┐    │          │
│  │  │              Main ALB + Keycloak ALB                │    │          │
│  │  └─────────────────────────────────────────────────────┘    │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │  Private Subnet  │  │  Private Subnet  │  │  Private Subnet  │          │
│  │    AZ-1 (a)      │  │    AZ-2 (b)      │  │    AZ-3 (c)      │          │
│  │  10.0.0.0/20     │  │  10.0.16.0/20    │  │  10.0.32.0/20    │          │
│  │                  │  │                  │  │                  │          │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │          │
│  │  │ ECS Tasks │  │  │  │ ECS Tasks │  │  │  │ ECS Tasks │  │          │
│  │  │ (Fargate) │  │  │  │ (Fargate) │  │  │  │ (Fargate) │  │          │
│  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │          │
│  │                  │  │                  │  │                  │          │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │          │
│  │  │ EFS Mount │  │  │  │ EFS Mount │  │  │  │ EFS Mount │  │          │
│  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │          │
│  │                  │  │                  │  │                  │          │
│  │  ┌─────────────────────────────────────────────────────┐    │          │
│  │  │         Aurora Serverless v2 + RDS Proxy            │    │          │
│  │  └─────────────────────────────────────────────────────┘    │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
│  VPC Endpoints: STS (Interface), S3 (Gateway)                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Network Stack (network-stack.yaml)

Creates VPC, subnets, gateways, security groups, and VPC endpoints.

**Resources:**
- `AWS::EC2::VPC` - Main VPC with DNS support
- `AWS::EC2::Subnet` (x6) - 3 public, 3 private subnets
- `AWS::EC2::InternetGateway` - Internet access for public subnets
- `AWS::EC2::NatGateway` (x3) - One per AZ for HA
- `AWS::EC2::EIP` (x3) - Elastic IPs for NAT Gateways
- `AWS::EC2::RouteTable` (x4) - 1 public, 3 private
- `AWS::EC2::Route` - Routes for internet and NAT
- `AWS::EC2::SubnetRouteTableAssociation` (x6)
- `AWS::EC2::VPCEndpoint` (x2) - STS interface, S3 gateway
- `AWS::EC2::SecurityGroup` - Main ALB SG
- `AWS::EC2::SecurityGroup` - Keycloak ALB SG
- `AWS::EC2::SecurityGroup` - ECS Tasks SG (Registry, Auth)
- `AWS::EC2::SecurityGroup` - Keycloak ECS SG
- `AWS::EC2::SecurityGroup` - MCP Servers SG
- `AWS::EC2::SecurityGroup` - Database SG
- `AWS::EC2::SecurityGroup` - EFS SG
- `AWS::EC2::SecurityGroup` - VPC Endpoints SG

**Exports:**
- VpcId, VpcCidr
- PublicSubnetIds, PrivateSubnetIds
- All security group IDs

### 2. Data Stack (data-stack.yaml)

Creates storage, database, and secrets management resources.

**Resources:**
- `AWS::EFS::FileSystem` - Encrypted EFS
- `AWS::EFS::MountTarget` (x3) - One per private subnet
- `AWS::EFS::AccessPoint` (x6) - servers, models, logs, agents, auth_config, mcpgw_data
- `AWS::KMS::Key` - Encryption key for RDS
- `AWS::KMS::Alias` - Key alias
- `AWS::RDS::DBSubnetGroup` - Subnet group
- `AWS::RDS::DBClusterParameterGroup` - MySQL parameters
- `AWS::RDS::DBCluster` - Aurora Serverless v2 cluster
- `AWS::RDS::DBInstance` - Serverless instance
- `AWS::RDS::DBProxy` - Connection pooling
- `AWS::RDS::DBProxyTargetGroup` - Proxy target
- `AWS::SecretsManager::Secret` - Database credentials
- `AWS::SecretsManager::Secret` - Keycloak client secrets
- `AWS::SecretsManager::Secret` - Admin password
- `AWS::SecretsManager::Secret` - Secret key
- `AWS::SSM::Parameter` (x5) - Keycloak SSM parameters

**Exports:**
- FileSystemId, AccessPointIds
- ClusterEndpoint, ProxyEndpoint
- Secret ARNs

### 3. Compute Stack (compute-stack.yaml)

Creates ECS clusters, load balancers, DNS, certificates, ECR, and IAM roles.

**Resources:**
- `AWS::ECS::Cluster` - Main MCP Gateway cluster
- `AWS::ECS::Cluster` - Keycloak cluster
- `AWS::ECS::ClusterCapacityProviderAssociations` (x2)
- `AWS::ServiceDiscovery::PrivateDnsNamespace` - Service Connect namespace
- `AWS::ElasticLoadBalancingV2::LoadBalancer` - Main ALB
- `AWS::ElasticLoadBalancingV2::LoadBalancer` - Keycloak ALB
- `AWS::ElasticLoadBalancingV2::TargetGroup` (x4) - registry, auth, gradio, keycloak
- `AWS::ElasticLoadBalancingV2::Listener` (x6) - HTTP, HTTPS, custom ports
- `AWS::CertificateManager::Certificate` - Registry cert
- `AWS::CertificateManager::Certificate` - Keycloak cert
- `AWS::Route53::RecordSet` - Registry A record
- `AWS::Route53::RecordSet` - Keycloak A record
- `AWS::ECR::Repository` - Keycloak repository
- `AWS::IAM::Role` - ECS Task Execution Role
- `AWS::IAM::Role` - ECS Task Role
- `AWS::IAM::Role` - Keycloak Task Execution/Task Roles
- `AWS::IAM::Role` - RDS Proxy Role
- `AWS::IAM::Policy` - Secrets Manager, SSM, ECS Exec policies

**Exports:**
- ClusterArns, ClusterNames
- ALB DNS names, ARNs, Zone IDs
- Target Group ARNs
- Certificate ARNs
- Role ARNs

### 4. Services Stack (services-stack.yaml)

Creates all ECS task definitions, services, and auto scaling.

**Resources:**
- `AWS::Logs::LogGroup` (x8) - Per-service logging
- `AWS::ECS::TaskDefinition` (x8) - All services
- `AWS::ECS::Service` (x8) - All services
- `AWS::ApplicationAutoScaling::ScalableTarget` (x8)
- `AWS::ApplicationAutoScaling::ScalingPolicy` (x16) - CPU and Memory policies

**Services:**
1. Registry (port 7860, 80, 443)
2. Auth Server (port 8888)
3. Keycloak (port 8080)
4. CurrentTime MCP (port 8000)
5. MCPGW MCP (port 8003)
6. RealServerFakeTools MCP (port 8002)
7. Flight Booking Agent (port 9000)
8. Travel Assistant Agent (port 9001)

## Data Models

### CloudFormation Parameters

```yaml
Parameters:
  # Network Configuration
  VpcCidr:
    Type: String
    Default: "10.0.0.0/16"
  
  IngressCidrBlocks:
    Type: CommaDelimitedList
    Default: "0.0.0.0/0"
  
  # Domain Configuration
  UseRegionalDomains:
    Type: String
    Default: "true"
    AllowedValues: ["true", "false"]
  
  BaseDomain:
    Type: String
    Default: "mycorp.click"
  
  HostedZoneId:
    Type: AWS::Route53::HostedZone::Id
  
  # Container Images
  RegistryImageUri:
    Type: String
  
  AuthServerImageUri:
    Type: String
  
  # ... (additional image URIs)
  
  # Credentials (NoEcho)
  KeycloakAdminPassword:
    Type: String
    NoEcho: true
    MinLength: 12
  
  KeycloakDatabasePassword:
    Type: String
    NoEcho: true
    MinLength: 12
```

### Stack Outputs Structure

```yaml
Outputs:
  VpcId:
    Value: !Ref VPC
    Export:
      Name: !Sub "${AWS::StackName}-VpcId"
  
  RegistryUrl:
    Value: !Sub "https://registry.${AWS::Region}.${BaseDomain}"
    Export:
      Name: !Sub "${AWS::StackName}-RegistryUrl"
  
  KeycloakUrl:
    Value: !Sub "https://kc.${AWS::Region}.${BaseDomain}"
    Export:
      Name: !Sub "${AWS::StackName}-KeycloakUrl"
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Based on the prework analysis, the following correctness properties can be verified for the CloudFormation deployment:

### Property 1: Task Definition Fargate Configuration
*For any* ECS task definition created by the CloudFormation templates, the task definition SHALL specify Fargate as the launch type and awsvpc as the network mode.
**Validates: Requirements 3.2**

### Property 2: Task Definition Logging Configuration
*For any* ECS task definition created by the CloudFormation templates, the container definition SHALL include CloudWatch logging configuration with a valid log group reference.
**Validates: Requirements 3.6**

### Property 3: Task Definition Health Check Configuration
*For any* ECS task definition created by the CloudFormation templates, the container definition SHALL include a health check with command, interval, timeout, retries, and startPeriod specified.
**Validates: Requirements 3.7**

### Property 4: Target Group Health Check Configuration
*For any* ALB target group created by the CloudFormation templates, the target group SHALL have health check configuration with path, protocol, and thresholds defined.
**Validates: Requirements 4.4**

### Property 5: EFS Access Point POSIX Configuration
*For any* EFS access point created by the CloudFormation templates, the access point SHALL configure POSIX user with UID 1000 and GID 1000.
**Validates: Requirements 6.4**

### Property 6: Regional Domain Name Pattern
*For any* domain name constructed when UseRegionalDomains is true, the domain SHALL follow the pattern {service}.{region}.{base_domain}.
**Validates: Requirements 7.4**

### Property 7: IAM Policy Least Privilege
*For any* IAM policy created by the CloudFormation templates, the policy SHALL use resource-specific ARNs rather than wildcards where the resource ARN is known at deployment time.
**Validates: Requirements 8.4**

### Property 8: Sensitive Parameter NoEcho
*For any* CloudFormation parameter that accepts sensitive data (passwords, secrets), the parameter SHALL be configured with NoEcho: true.
**Validates: Requirements 9.3**

### Property 9: Log Group Retention Configuration
*For any* CloudWatch Log Group created for ECS services, the log group SHALL have RetentionInDays set to 30 (or 7 for Keycloak).
**Validates: Requirements 11.1**

### Property 10: ECS Security Group Ingress Restriction
*For any* ECS task security group, ingress rules SHALL only reference the associated ALB security group or other authorized service security groups, not open CIDR blocks.
**Validates: Requirements 12.3**

### Property 11: Parameter Defaults Match Terraform
*For any* CloudFormation parameter with a default value, the default SHALL match the corresponding default value in the Terraform configuration.
**Validates: Requirements 13.3**

## Error Handling

### Stack Creation Failures

1. **Rollback on Failure**: All stacks configured with `OnFailure: ROLLBACK` to ensure clean state on errors
2. **DependsOn**: Explicit dependencies between nested stacks to ensure correct creation order
3. **Condition Functions**: Use `Fn::If` for optional resources based on parameters

### Certificate Validation

1. **DNS Validation**: ACM certificates use DNS validation with Route53
2. **Timeout Handling**: Certificate resources include appropriate creation timeouts
3. **Validation Records**: Automatic creation of CNAME records for validation

### Database Initialization

1. **Secrets Rotation**: Secrets Manager secrets configured for rotation capability
2. **Connection Retry**: RDS Proxy handles connection pooling and retry logic
3. **Encryption**: KMS key with deletion protection and rotation

## Testing Strategy

### Dual Testing Approach

The CloudFormation deployment will be validated using both unit testing (template validation) and property-based testing (deployment verification).

#### Unit Testing with cfn-lint and taskcat

1. **Template Syntax Validation**
   - Use `cfn-lint` to validate all CloudFormation templates
   - Check for syntax errors, invalid resource types, and best practice violations

2. **Template Testing with taskcat**
   - Deploy templates to test AWS account
   - Verify stack creation succeeds
   - Validate outputs are correct

#### Property-Based Testing with pytest and boto3

1. **Property Test Framework**: pytest with hypothesis for property-based testing
2. **AWS SDK**: boto3 for querying deployed resources
3. **Test Configuration**: Minimum 100 iterations per property test

**Property Test Implementation Pattern:**
```python
# Example property test structure
# **Feature: cloudformation-deployment, Property 1: Task Definition Fargate Configuration**
@given(task_definition=st.sampled_from(deployed_task_definitions))
def test_task_definition_fargate_mode(task_definition):
    """All task definitions must use Fargate launch type and awsvpc network mode."""
    assert task_definition['requiresCompatibilities'] == ['FARGATE']
    assert task_definition['networkMode'] == 'awsvpc'
```

#### Integration Testing

1. **End-to-End Deployment**: Full stack deployment to test account
2. **Service Health Checks**: Verify all ECS services reach healthy state
3. **Connectivity Tests**: Verify ALB endpoints respond correctly
4. **DNS Resolution**: Verify Route53 records resolve to correct ALB

### Test Execution Order

1. Run `cfn-lint` on all templates
2. Deploy to test environment with taskcat
3. Execute property-based tests against deployed resources
4. Run integration tests for service connectivity
5. Cleanup test resources
