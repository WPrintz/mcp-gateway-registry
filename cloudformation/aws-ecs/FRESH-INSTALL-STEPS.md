# Fresh Install Steps for MCP Gateway Registry

## Prerequisites
- AWS CLI configured with appropriate credentials
- Templates already uploaded to S3 (done on 2025-12-12)

## S3 Template Location
- Bucket: `ws-event-5d3c487e-11d-us-west-2`
- Prefix: `a6f4da68-c278-4188-b814-5a63ab4be171/assets/`

## Step 1: Delete Existing Stack (if any)

```bash
# Check if stack exists
aws cloudformation describe-stacks --stack-name main-stack --region us-west-2 2>&1 | head -5

# If it exists, delete it
aws cloudformation delete-stack --stack-name main-stack --region us-west-2

# Wait for deletion (can take 20-30 minutes due to Aurora, EFS, etc.)
aws cloudformation wait stack-delete-complete --stack-name main-stack --region us-west-2
```

If the stack is stuck in DELETE_FAILED, you may need to manually delete resources:
```bash
# Check what failed
aws cloudformation describe-stack-events --stack-name main-stack \
  --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
  --region us-west-2 --output table
```

## Step 2: Deploy Fresh Stack

```bash
aws cloudformation create-stack \
  --stack-name main-stack \
  --template-url https://ws-event-5d3c487e-11d-us-west-2.s3.us-west-2.amazonaws.com/a6f4da68-c278-4188-b814-5a63ab4be171/assets/main-stack.yaml \
  --parameters \
    ParameterKey=TemplateS3Bucket,ParameterValue=ws-event-5d3c487e-11d-us-west-2 \
    ParameterKey=TemplateS3Prefix,ParameterValue=a6f4da68-c278-4188-b814-5a63ab4be171/assets/ \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2
```

## Step 3: Monitor Deployment

```bash
# Check overall status
aws cloudformation describe-stacks --stack-name main-stack \
  --query 'Stacks[0].StackStatus' --region us-west-2 --output text

# Watch nested stack progress
watch -n 30 'aws cloudformation list-stacks \
  --stack-status-filter CREATE_IN_PROGRESS CREATE_COMPLETE CREATE_FAILED \
  --query "StackSummaries[?contains(StackName, \`main-stack\`)].[StackName,StackStatus]" \
  --region us-west-2 --output table'
```

### Expected Timeline
- Network Stack: ~3 minutes
- Data Stack: ~20 minutes (Aurora Serverless takes time)
- Compute Stack: ~12 minutes (includes CodeBuild for container images)
- Services Stack: ~25 minutes (ECS services, health checks)
- **Total: ~45-60 minutes**

## Step 4: Verify Deployment

```bash
# Get the CloudFront URLs
aws cloudformation describe-stacks --stack-name main-stack \
  --query 'Stacks[0].Outputs[?contains(OutputKey, `Url`)].[OutputKey,OutputValue]' \
  --region us-west-2 --output table

# Check ECS services are running
aws ecs list-services --cluster mcp-gateway-ecs-cluster --region us-west-2

# Check service health
aws ecs describe-services --cluster mcp-gateway-ecs-cluster \
  --services mcp-gateway-registry mcp-gateway-auth-server \
  --query 'services[*].[serviceName,runningCount,desiredCount]' \
  --region us-west-2 --output table
```

## Step 5: Verify DNS Resolution (Optional)

```bash
# Get a task ID
TASK_ID=$(aws ecs list-tasks --cluster mcp-gateway-ecs-cluster \
  --service-name mcp-gateway-registry --query 'taskArns[0]' \
  --region us-west-2 --output text | cut -d'/' -f3)

# Test DNS resolution from inside the container
aws ecs execute-command --cluster mcp-gateway-ecs-cluster \
  --task $TASK_ID --container registry \
  --command "python -c \"import socket; print(socket.gethostbyname('currenttime-server.mcp-gateway.local'))\"" \
  --interactive --region us-west-2
```

## Troubleshooting

### Stack Creation Failed
```bash
# Check which resource failed
aws cloudformation describe-stack-events --stack-name main-stack \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
  --region us-west-2 --output table
```

### ECS Services Not Starting
```bash
# Check service events
aws ecs describe-services --cluster mcp-gateway-ecs-cluster \
  --services mcp-gateway-registry \
  --query 'services[0].events[0:5]' \
  --region us-west-2 --output json
```

### DNS Resolution Still Failing
```bash
# Check Cloud Map services exist
aws servicediscovery list-services \
  --filters Name=NAMESPACE_ID,Values=<namespace-id> \
  --region us-west-2 --output table

# Check instances are registered
aws servicediscovery list-instances --service-id <service-id> --region us-west-2
```

## Key Changes in This Deployment

This deployment uses **DNS-based service discovery** instead of Service Connect:

1. Cloud Map services are created with `DnsConfig` (Type A records)
2. ECS services use `ServiceRegistries` (no `ServiceConnectConfiguration`)
3. Route53 A records are automatically created for each service
4. DNS resolution works from any container in the VPC

See `docs/service-connect-dns-issue.md` for full details on why this approach was chosen.
