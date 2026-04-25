# Workshop Participant IAM Policy

## Overview

This IAM policy grants workshop participants the minimum permissions required to complete all labs in the "Securing AI Agent Ecosystems with MCP Gateway and Registry" workshop.

## Policy File

**File:** `cloudformation/aws-ecs/static/workshop-participant-iam-policy.json`

**Validation Status:** ✅ Validated with AWS IAM Access Analyzer (no findings)

## Permissions Breakdown

### 1. CloudFormation Access (Read-Only)
**Purpose:** View all stack outputs, nested stacks, templates, and infrastructure details

- `cloudformation:DescribeStacks` - View stack details and outputs (main and nested)
- `cloudformation:DescribeStackResource` - Get details on individual stack resources
- `cloudformation:DescribeStackResources` - List resources in stacks
- `cloudformation:DescribeStackEvents` - View stack creation/update events
- `cloudformation:GetTemplate` - Retrieve stack templates (all stacks and nested stacks)
- `cloudformation:ListStacks` - List all stacks in the account
- `cloudformation:ListStackResources` - List stack resource summaries

**Resource Scope:** All stacks (main, nested, load-generator, etc.)

**Used in:**
- Module 1, Step 1: Retrieve URLs from stack outputs
- Module 2, Step 4: Query stack outputs via CLI
- Module 3, Step 3: Explore nested stack architecture
- Learning: View templates to understand deployment architecture
- Learning: Inspect nested stack outputs and resource dependencies

---

### 2. Secrets Manager Access (Read-Only)
**Purpose:** Retrieve the MCP Gateway admin password

- `secretsmanager:GetSecretValue` - Retrieve secret value
- `secretsmanager:DescribeSecret` - View secret metadata
- `secretsmanager:ListSecrets` - Browse secrets in the console (resource: `*`)

**Resource Scope:** `GetSecretValue` and `DescribeSecret` limited to `mcp-gateway-admin-password` secret only. `ListSecrets` requires `*` (API limitation) but only exposes metadata, not secret values.

**Used in:**
- Module 1, Step 1: Retrieve admin password for initial login

---

### 3. SSM Parameter Store Access (Read-Only)
**Purpose:** Retrieve Keycloak admin credentials

- `ssm:GetParameter` - Get individual parameter
- `ssm:GetParameters` - Get multiple parameters
- `ssm:DescribeParameters` - Browse parameters in the console (resource: `*`)
- `kms:Decrypt` - Decrypt SecureString parameter values (conditioned on `kms:ViaService: ssm.us-west-2.amazonaws.com`)

**Resource Scope:** `GetParameter`/`GetParameters` limited to:
- `/keycloak/admin` - Keycloak admin username (SecureString)
- `/keycloak/admin_password` - Keycloak admin password (SecureString)

`DescribeParameters` requires `*` (API limitation, returns metadata only). `kms:Decrypt` scoped via condition key to SSM service only.

**Used in:**
- Module 3, Step 3: Access Keycloak Admin Console to modify group membership

---

### 4. CloudWatch Logs Access (Read-Only + Insights)
**Purpose:** View and query application logs for observability

- `logs:DescribeLogGroups` - List available log groups
- `logs:DescribeLogStreams` - List log streams within groups
- `logs:GetLogEvents` - View log entries
- `logs:FilterLogEvents` - Filter logs by pattern
- `logs:StartQuery` - Start CloudWatch Logs Insights query
- `logs:StopQuery` - Stop running query
- `logs:GetQueryResults` - Retrieve query results
- `logs:DescribeQueries` - List query status

**Resource Scope:** Limited to MCP Gateway log groups:
- `/ecs/mcp-gateway-registry` - Registry API logs
- `/ecs/mcp-gateway-nginx` - Proxy/routing logs
- `/ecs/mcp-gateway-keycloak` - Authentication logs
- `/ecs/mcp-gateway-auth-server` - Authorization server logs

**Used in:**
- Module 11, Step 2: View and filter CloudWatch logs
- Module 11, Step 2: Run Logs Insights queries

---

### 5. CloudWatch Metrics Access (Read-Only)
**Purpose:** View metrics and dashboards

- `cloudwatch:DescribeAlarms` - View alarm status
- `cloudwatch:GetMetricStatistics` - Retrieve metric data
- `cloudwatch:ListMetrics` - List available metrics
- `cloudwatch:GetMetricData` - Get metric data points
- `cloudwatch:DescribeAlarmsForMetric` - View alarms for specific metrics

**Resource Scope:** All CloudWatch metrics (required for console navigation)

**Used in:**
- Module 11, Step 1: View health metrics
- Module 11, Step 3: View custom metrics

---

### 6. CloudWatch Alarms Write Access
**Purpose:** Create and manage alarms during observability exercises

- `cloudwatch:PutMetricAlarm` - Create or update alarms
- `cloudwatch:DeleteAlarms` - Delete alarms

**Resource Scope:** Limited to alarms with prefix `mcp-gateway-*`

**Used in:**
- Module 7, Step 3: Create custom alarms for agent monitoring
- Module 11, Step 3: Configure metric alarms

---

### 7. CloudWatch Log Metric Filters
**Purpose:** Create custom metrics from log patterns

- `logs:PutMetricFilter` - Create metric filter
- `logs:DeleteMetricFilter` - Remove metric filter
- `logs:DescribeMetricFilters` - List existing filters

**Resource Scope:** Limited to MCP Gateway log groups

**Used in:**
- Module 7, Step 3: Create metric filters for agent activity
- Module 11, Step 3: Configure log-based metrics

---

### 8. CloudShell Access
**Purpose:** Execute AWS CLI commands from browser-based shell

- `cloudshell:CreateEnvironment` - Launch CloudShell
- `cloudshell:CreateSession` - Start shell session
- `cloudshell:GetEnvironmentStatus` - Check environment status
- `cloudshell:DeleteEnvironment` - Clean up environment
- `cloudshell:PutCredentials` - Use session credentials

**Resource Scope:** All CloudShell resources

**Used in:**
- Module 1, Step 1: Optional CLI-based password retrieval
- Module 2, Step 4: Get API tokens and test MCP protocol
- Module 3, Step 3: Modify access control via API

---

### 9. EC2 Read-Only (Supporting CloudShell)
**Purpose:** CloudShell requires VPC/subnet information

- `ec2:DescribeVpcs` - List VPCs
- `ec2:DescribeSubnets` - List subnets

**Resource Scope:** All VPCs (required by CloudShell service)

**Used in:** Background requirement for CloudShell functionality

---

### 10. CloudWatch Extended Read-Only
**Purpose:** View dashboards, alarm history, and insight rules in the CloudWatch console

- `cloudwatch:DescribeAlarmHistory` - View alarm state change history
- `cloudwatch:DescribeInsightRules` - List CloudWatch Contributor Insights rules
- `cloudwatch:GetDashboard` - Retrieve dashboard definitions
- `cloudwatch:GetInsightRuleReport` - Get Contributor Insights report data
- `cloudwatch:GetMetricWidgetImage` - Render metric graph images
- `cloudwatch:ListDashboards` - List available dashboards
- `cloudwatch:ListTagsForResource` - View tags on CloudWatch resources

**Resource Scope:** All CloudWatch resources (required for console navigation)

**Used in:**
- Module 11: Browse CloudWatch dashboards and alarm history

---

### 11. ECS Read-Only (Container Insights)
**Purpose:** View ECS cluster, service, and task details in Container Insights

- `ecs:DescribeClusters` - View cluster details
- `ecs:DescribeContainerInstances` - View container instance details
- `ecs:DescribeServices` - View service configuration and status
- `ecs:DescribeTasks` - View running task details
- `ecs:DescribeTaskDefinition` - View task definition configuration
- `ecs:ListClusters` - List ECS clusters
- `ecs:ListContainerInstances` - List container instances
- `ecs:ListServices` - List services in a cluster
- `ecs:ListTasks` - List running tasks
- `ecs:ListTaskDefinitions` - List task definition revisions
- `ecs:ListTagsForResource` - View tags on ECS resources

**Resource Scope:** All ECS resources (required for Container Insights console)

**Used in:**
- Module 11: View Container Insights dashboards, service health, and task metrics

---

### 12. Application Insights Read-Only
**Purpose:** View CloudWatch Application Insights for application-level monitoring

- `applicationinsights:DescribeApplication` - View application configuration
- `applicationinsights:DescribeComponent` - View component details
- `applicationinsights:DescribeComponentConfiguration` - View monitoring configuration
- `applicationinsights:DescribeObservation` - View individual observations
- `applicationinsights:DescribeProblem` - View detected problems
- `applicationinsights:ListApplications` - List monitored applications
- `applicationinsights:ListComponents` - List application components
- `applicationinsights:ListProblems` - List detected problems

**Resource Scope:** All Application Insights resources

**Used in:**
- Module 11: View application-level health and problem detection

---

### 13. X-Ray Read-Only (ServiceLens / Container Insights Service Map)
**Purpose:** View service maps, traces, and sampling configuration

- `xray:GetServiceGraph` - View service dependency map
- `xray:GetTraceGraph` - View individual trace graphs
- `xray:GetTraceSummaries` - List trace summaries
- `xray:GetSamplingRules` - View sampling configuration
- `xray:GetSamplingTargets` - View sampling targets
- `xray:GetSamplingStatisticSummaries` - View sampling statistics
- `xray:BatchGetTraces` - Retrieve full trace data
- `xray:GetGroup` - View X-Ray group configuration (required for Container Insights service map)
- `xray:GetGroups` - List X-Ray groups (required for Container Insights service map)

**Resource Scope:** All X-Ray resources

**Used in:**
- Module 11: View Container Insights service map and distributed traces

---

### 14. Resource Tagging Read-Only
**Purpose:** Browse resources by tag in the AWS console

- `tag:GetResources` - List resources by tag
- `tag:GetTagKeys` - List tag keys
- `tag:GetTagValues` - List tag values

**Resource Scope:** All tagged resources

**Used in:** Background requirement for console resource filtering

---

### 15. Auto Scaling Read-Only
**Purpose:** View auto scaling configuration in the console

- `autoscaling:DescribeAutoScalingGroups` - View scaling group details
- `autoscaling:DescribeScalingActivities` - View scaling events

**Resource Scope:** All Auto Scaling resources

**Used in:** Background requirement for Container Insights and ECS console views

---

### 16. Elastic Load Balancing Read-Only
**Purpose:** View load balancer configuration and target health

- `elasticloadbalancing:DescribeLoadBalancers` - List load balancers
- `elasticloadbalancing:DescribeTargetGroups` - View target group configuration
- `elasticloadbalancing:DescribeTargetHealth` - View target health status
- `elasticloadbalancing:DescribeListeners` - View listener configuration
- `elasticloadbalancing:DescribeRules` - View routing rules
- `elasticloadbalancing:DescribeTags` - View load balancer tags

**Resource Scope:** All ELB resources

**Used in:** Background requirement for Container Insights and service health views

---

## Security Considerations

### Read-Only First Principle
The policy grants **read-only** access to all sensitive resources:
- CloudFormation stacks including nested stacks and templates (cannot modify or delete)
- Secrets Manager secrets (cannot create or update)
- SSM parameters (cannot modify values)
- CloudWatch logs (cannot delete or modify)

### Write Access Scoped to Non-Sensitive Resources
Write permissions are limited to:
- **CloudWatch Alarms** - Workshop participants can create alarms with `mcp-gateway-*` prefix only
- **Log Metric Filters** - Can create filters on MCP Gateway log groups only
- **CloudShell** - Ephemeral shell environment with inherited IAM permissions

### Resource-Level Restrictions
Where possible, permissions are scoped to specific resources:
- CloudFormation: `main-stack` only
- Secrets Manager: `mcp-gateway-admin-password` only
- SSM: Keycloak credentials only
- CloudWatch Logs: MCP Gateway log groups only
- CloudWatch Alarms: `mcp-gateway-*` prefix only

### No Infrastructure Modification
Participants **cannot**:
- Create, update, or delete CloudFormation stacks
- Modify ECS services, tasks, or task definitions
- Change VPC networking, security groups, or load balancers
- Modify DocumentDB/MongoDB databases
- Create or modify IAM roles or policies
- Access other AWS accounts or regions (scoped to `us-west-2`)

---

## Usage Instructions

### For Workshop Studio Deployment

1. **Create the IAM policy:**
   ```bash
   aws iam create-policy \
     --policy-name MCPGatewayWorkshopParticipantPolicy \
     --policy-document file://cloudformation/aws-ecs/static/workshop-participant-iam-policy.json \
     --description "Permissions for MCP Gateway workshop participants" \
     --region us-west-2
   ```

2. **Attach to Workshop Studio participant role:**
   ```bash
   aws iam attach-role-policy \
     --role-name WorkshopStudioParticipantRole \
     --policy-arn arn:aws:iam::ACCOUNT_ID:policy/MCPGatewayWorkshopParticipantPolicy
   ```

### For Event Engine Deployment

1. Upload `cloudformation/aws-ecs/static/workshop-participant-iam-policy.json` to Event Engine
2. Attach to the participant team role during event setup

### For Self-Paced Learning

1. Create the policy in your AWS account
2. Create a new IAM user or role
3. Attach the policy
4. Use the credentials to access the workshop environment

---

## Testing the Policy

After deploying, verify permissions with these commands:

```bash
# Test CloudFormation access
aws cloudformation describe-stacks --stack-name main-stack --region us-west-2

# Test Secrets Manager access
aws secretsmanager get-secret-value --secret-id mcp-gateway-admin-password --region us-west-2

# Test SSM Parameter Store access
aws ssm get-parameter --name /keycloak/admin --region us-west-2

# Test CloudWatch Logs access
aws logs describe-log-groups --log-group-name-prefix /ecs/mcp-gateway --region us-west-2

# Test CloudWatch Metrics access
aws cloudwatch list-metrics --namespace AWS/ECS --region us-west-2
```

All commands should succeed. Commands outside the scope should fail with `AccessDenied`.

---

## Policy Version

**Version:** 1.1
**Last Updated:** 2026-02-16
**Compatible with Workshop Version:** v1.0.12+

---

## Support

For issues or questions about permissions, contact the workshop administrators or file an issue in the [mcp-gateway-registry repository](https://github.com/agentic-community/mcp-gateway-registry).
