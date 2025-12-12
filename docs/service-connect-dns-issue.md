# Service Connect DNS Resolution Issue

## Problem Summary

MCP servers and agents show as "unhealthy" in the Registry UI because health checks fail with DNS resolution errors:
```
socket.gaierror: [Errno -2] Name or service not known
```

The registry container cannot resolve DNS names like `currenttime-server`, `mcpgw-server`, or `travel-assistant-agent.mcp-gateway.local`.

## Root Cause Analysis

### Service Connect Configuration
- Service Connect is enabled on all ECS services
- Each service publishes its `ClientAliases` with DNS names (e.g., `currenttime-server:8000`)
- The Service Connect Envoy proxy sidecar is running in each task

### Cloud Map Service Registration
- Namespace: `mcp-gateway.local` (Type: `DNS_PRIVATE`)
- Services are registered as **HTTP type** (not DNS_HTTP)
- HTTP type services have empty `DnsConfig: {}`
- **No A records are created in Route53** for the service names

### DNS Resolution Flow
1. Registry container calls `httpx.AsyncClient.post("http://currenttime-server:8000/mcp")`
2. Python's httpx library resolves DNS using system resolver (`/etc/resolv.conf`)
3. `/etc/resolv.conf` points to VPC DNS (`10.0.0.2`)
4. VPC DNS queries Route53 private hosted zone `mcp-gateway.local`
5. **No A record exists** → DNS resolution fails

### Why Service Connect DNS Interception Doesn't Work
Service Connect is designed to intercept connections via the Envoy proxy, but:
1. The proxy intercepts based on **destination port**, not DNS
2. DNS resolution happens **before** the connection attempt
3. HTTP-type Cloud Map services don't create DNS records
4. The application never gets to the connection phase because DNS fails first

## Evidence

```bash
# Cloud Map service is HTTP type with no DNS config
aws servicediscovery get-service --id srv-r4k2vqzn6yfg7exy --region us-west-2
# Output: "Type": "HTTP", "DnsConfig": {}

# Route53 hosted zone has no A records
aws route53 list-resource-record-sets --hosted-zone-id Z08549651ZAY6VKN9GR00
# Output: Only NS and SOA records, no A records

# Container resolv.conf points to VPC DNS
aws ecs execute-command --cluster mcp-gateway-ecs-cluster \
  --task <task-id> --container registry \
  --command "cat /etc/resolv.conf"
# Output: nameserver 10.0.0.2

# DNS resolution fails
aws ecs execute-command --cluster mcp-gateway-ecs-cluster \
  --task <task-id> --container registry \
  --command "python -c \"import socket; print(socket.gethostbyname('currenttime-server'))\""
# Output: socket.gaierror: [Errno -2] Name or service not known
```

## Solution Options

### Option 1: Use Cloud Map DNS Service Discovery (Recommended)

Create separate Cloud Map services with DNS configuration that creates A records:

```yaml
# Add to services-stack.yaml for each MCP server
CurrentTimeDiscoveryService:
  Type: AWS::ServiceDiscovery::Service
  Properties:
    Name: currenttime-server
    NamespaceId: !ImportValue
      Fn::Sub: ${EnvironmentName}-ServiceDiscoveryNamespaceId
    DnsConfig:
      DnsRecords:
        - Type: A
          TTL: 10
      RoutingPolicy: MULTIVALUE
    HealthCheckCustomConfig:
      FailureThreshold: 1
```

Then register instances when tasks start, or use ECS service registries.

### Option 2: Use ECS Service Registries (Alternative)

Add `ServiceRegistries` to ECS services instead of/in addition to Service Connect:

```yaml
CurrentTimeService:
  Type: AWS::ECS::Service
  Properties:
    # ... existing config ...
    ServiceRegistries:
      - RegistryArn: !GetAtt CurrentTimeDiscoveryService.Arn
        ContainerName: currenttime-server
        ContainerPort: 8000
```

This creates DNS A records that resolve to task IPs.

### Option 3: Use IP Addresses (Workaround)

Modify the MCP server registration Lambda to:
1. Query Cloud Map API for service instance IPs
2. Use IP addresses in `proxy_pass_url` instead of DNS names

```python
import boto3

def get_service_ip(service_name, namespace_id):
    sd = boto3.client('servicediscovery')
    instances = sd.discover_instances(
        NamespaceName='mcp-gateway.local',
        ServiceName=service_name
    )
    if instances['Instances']:
        return instances['Instances'][0]['Attributes']['AWS_INSTANCE_IPV4']
    return None
```

**Drawback:** IPs change when tasks restart, requiring re-registration.

### Option 4: Upstream Code Change

Modify the registry health check code to use Cloud Map API for service discovery instead of DNS:

```python
# In registry/health/service.py
async def _resolve_service_endpoint(self, service_name: str) -> str:
    """Resolve service endpoint using Cloud Map API."""
    import boto3
    sd = boto3.client('servicediscovery')
    response = sd.discover_instances(
        NamespaceName='mcp-gateway.local',
        ServiceName=service_name
    )
    if response['Instances']:
        ip = response['Instances'][0]['Attributes']['AWS_INSTANCE_IPV4']
        port = response['Instances'][0]['Attributes']['AWS_INSTANCE_PORT']
        return f"http://{ip}:{port}"
    raise Exception(f"Service {service_name} not found in Cloud Map")
```

## Recommended Fix

**Option 2 (ECS Service Registries)** is the cleanest solution because:
1. It's a CloudFormation-only change (no code changes)
2. ECS automatically manages instance registration/deregistration
3. DNS records are created and updated automatically
4. Works with existing health check code

## Implementation (COMPLETED)

The fix has been implemented in the CloudFormation templates using **Option B: DNS-based service discovery only** (no Service Connect).

### Key Learning: Service Connect vs DNS Discovery

**IMPORTANT:** Service Connect and DNS-based ServiceRegistries are mutually exclusive for the same service names. You must choose one approach:

- **Service Connect**: Creates HTTP-type Cloud Map services, uses Envoy proxy for routing
- **DNS-based ServiceRegistries**: Creates DNS-type Cloud Map services with A records

If both are configured, they conflict because they try to create Cloud Map services with the same names. The templates have been updated to use DNS-based discovery only.

### Changes to compute-stack.yaml
Added Cloud Map services with DNS configuration for each service:
- `CurrentTimeDiscoveryService`
- `McpgwDiscoveryService`
- `RealServerFakeToolsDiscoveryService`
- `FlightBookingAgentDiscoveryService`
- `TravelAssistantAgentDiscoveryService`
- `AuthServerDiscoveryService`
- `RegistryDiscoveryService`

Each service is configured with:
```yaml
DnsConfig:
  DnsRecords:
    - Type: A
      TTL: 10
  RoutingPolicy: MULTIVALUE
HealthCheckCustomConfig:
  FailureThreshold: 1
```

Added exports for each discovery service ARN.

### Changes to services-stack.yaml
1. **Removed** all `ServiceConnectConfiguration` blocks from ECS services
2. **Added** `ServiceRegistries` to each ECS service:
```yaml
ServiceRegistries:
  - RegistryArn: !ImportValue
      Fn::Sub: ${EnvironmentName}-CurrentTimeDiscoveryServiceArn
    ContainerName: currenttime-server
```

Note: `ContainerPort` is NOT specified because DNS_HTTP type services don't require it.

### Fresh Deployment Steps

If you have an existing deployment with Service Connect, you need a fresh install:

```bash
# 1. Delete the existing stack (this will take ~30 minutes)
aws cloudformation delete-stack --stack-name main-stack --region us-west-2

# 2. Wait for deletion to complete
aws cloudformation wait stack-delete-complete --stack-name main-stack --region us-west-2

# 3. Deploy fresh with the updated templates
aws cloudformation create-stack \
  --stack-name main-stack \
  --template-url https://ws-event-5d3c487e-11d-us-west-2.s3.us-west-2.amazonaws.com/a6f4da68-c278-4188-b814-5a63ab4be171/assets/main-stack.yaml \
  --parameters \
    ParameterKey=TemplateS3Bucket,ParameterValue=ws-event-5d3c487e-11d-us-west-2 \
    ParameterKey=TemplateS3Prefix,ParameterValue=a6f4da68-c278-4188-b814-5a63ab4be171/assets/ \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-west-2

# 4. Monitor deployment (~45 minutes total)
aws cloudformation describe-stacks --stack-name main-stack --query 'Stacks[0].StackStatus' --region us-west-2
```

### How It Works After Deployment
1. Compute-stack creates Cloud Map services with DNS configuration
2. Services-stack creates ECS services with ServiceRegistries
3. ECS automatically registers task IPs with Cloud Map when tasks start
4. Route53 A records are created for each service (e.g., `currenttime-server.mcp-gateway.local`)
5. DNS resolution works from any container in the VPC
6. Health checks can resolve service names and verify connectivity

## Related Issues

- CloudFront/ALB Session Cookie Secure Issue (see `docs/cloudfront-alb-cookie-secure-issue.md`)
- Both issues stem from the CloudFormation deployment architecture differences from Terraform
