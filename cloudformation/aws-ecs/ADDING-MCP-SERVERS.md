# Adding or Removing MCP Servers in CloudFormation

This guide documents the steps required to add or remove MCP servers/agents from the CloudFormation deployment.

## Why Multiple Files?

Due to how ECS Service Connect works with Cloud Map, we need:
1. **Cloud Map Discovery Service** (DNS records) - in compute-stack.yaml
2. **ECS Service + Task Definition** - in services-stack.yaml  
3. **Server Registration** (optional) - in data-stack.yaml Lambda

See `docs/service-connect-dns-issue.md` for technical details on why DNS-based service discovery is required.

---

## Checklist: Adding a New MCP Server

### Step 1: compute-stack.yaml - Cloud Map Discovery Service

Add a new Cloud Map service for DNS resolution:

```yaml
  # After the existing discovery services (around line 350)
  MyNewServerDiscoveryService:
    Type: AWS::ServiceDiscovery::Service
    Properties:
      Name: mynewserver-server  # Must match DnsName in services-stack
      NamespaceId: !Ref ServiceDiscoveryNamespace
      Description: DNS service discovery for MyNewServer MCP server
      DnsConfig:
        DnsRecords:
          - Type: A
            TTL: 10
        RoutingPolicy: MULTIVALUE
      HealthCheckCustomConfig:
        FailureThreshold: 1
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-mynewserver-discovery
```

Add the export in Outputs section:

```yaml
  MyNewServerDiscoveryServiceArn:
    Description: MyNewServer Cloud Map Discovery Service ARN
    Value: !GetAtt MyNewServerDiscoveryService.Arn
    Export:
      Name: !Sub ${EnvironmentName}-MyNewServerDiscoveryServiceArn
```

### Step 2: services-stack.yaml - Parameters

Add image parameters:

```yaml
  MyNewServerImageRepo:
    Type: String
    Default: 'mcp-gateway-mynewserver'
    Description: ECR repository name for MyNewServer MCP server

  MyNewServerImageTag:
    Type: String
    Default: 'latest'
    Description: Image tag for MyNewServer MCP server
```

### Step 3: services-stack.yaml - Log Group

```yaml
  MyNewServerLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub /ecs/${EnvironmentName}-mynewserver
      RetentionInDays: 30
```

### Step 4: services-stack.yaml - Task Definition

```yaml
  MyNewServerTaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: !Sub ${EnvironmentName}-mynewserver
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      Cpu: '512'
      Memory: '1024'
      ExecutionRoleArn: !ImportValue
        Fn::Sub: ${EnvironmentName}-EcsTaskExecutionRoleArn
      TaskRoleArn: !ImportValue
        Fn::Sub: ${EnvironmentName}-EcsTaskRoleArn
      ContainerDefinitions:
        - Name: mynewserver-server
          Image: !Sub '${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/${MyNewServerImageRepo}:${MyNewServerImageTag}'
          Essential: true
          PortMappings:
            - Name: mynewserver
              ContainerPort: 8000  # Your server's port
              Protocol: tcp
          Environment:
            - Name: PORT
              Value: '8000'
            - Name: MCP_TRANSPORT
              Value: streamable-http
          LogConfiguration:
            LogDriver: awslogs
            Options:
              awslogs-group: !Ref MyNewServerLogGroup
              awslogs-region: !Ref AWS::Region
              awslogs-stream-prefix: ecs
          HealthCheck:
            Command:
              - CMD-SHELL
              - nc -z localhost 8000 || exit 1
            Interval: 30
            Timeout: 5
            Retries: 3
            StartPeriod: 30
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-mynewserver
```

### Step 5: services-stack.yaml - ECS Service

```yaml
  MyNewServerService:
    Type: AWS::ECS::Service
    DependsOn: RegistryService
    Properties:
      ServiceName: !Sub ${EnvironmentName}-mynewserver
      Cluster: !ImportValue
        Fn::Sub: ${EnvironmentName}-MainEcsClusterArn
      TaskDefinition: !Ref MyNewServerTaskDefinition
      DesiredCount: !Ref MinCapacity
      LaunchType: FARGATE
      EnableExecuteCommand: true
      NetworkConfiguration:
        AwsvpcConfiguration:
          AssignPublicIp: DISABLED
          SecurityGroups:
            - !ImportValue
              Fn::Sub: ${EnvironmentName}-McpServersSG
          Subnets: !Split
            - ','
            - !ImportValue
              Fn::Sub: ${EnvironmentName}-PrivateSubnets
      ServiceConnectConfiguration:
        Enabled: true
        Namespace: !ImportValue
          Fn::Sub: ${EnvironmentName}-ServiceDiscoveryNamespaceArn
        Services:
          - PortName: mynewserver
            ClientAliases:
              - Port: 8000
                DnsName: mynewserver-server  # Must match Cloud Map service name
            DiscoveryName: mynewserver-server
      ServiceRegistries:
        - RegistryArn: !ImportValue
            Fn::Sub: ${EnvironmentName}-MyNewServerDiscoveryServiceArn
          ContainerName: mynewserver-server
          ContainerPort: 8000
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-mynewserver
```

### Step 6: data-stack.yaml - Server Registration (Optional)

If you want the server pre-registered in the registry on deployment, add to the `MCP_SERVERS` list in the Lambda:

```python
{
    "server_name": "mynewserver-server",
    "path": "/mcp/mynewserver",
    "description": "Description of your MCP server",
    "tags": ["tag1", "tag2"],
    "proxy_pass_url": "http://mynewserver-server:8000",
    "is_python": True,
    "num_tools": 1,
    "tool_list": [
        {
            "name": "my_tool",
            "description": "What the tool does"
        }
    ]
}
```

### Step 7: compute-stack.yaml - ECR Repository (if building from source)

Add ECR repository in the CodeBuild section:

```yaml
  MyNewServerEcrRepository:
    Type: AWS::ECR::Repository
    Properties:
      RepositoryName: !Sub ${EnvironmentName}-mynewserver
      ImageScanningConfiguration:
        ScanOnPush: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-mynewserver
```

And add to buildspec in ContainerBuildProject.

---

## Checklist: Removing an MCP Server

Remove in reverse order:

1. **services-stack.yaml**: Remove Service, Task Definition, Log Group, Parameters
2. **compute-stack.yaml**: Remove Discovery Service, Export, ECR Repository
3. **data-stack.yaml**: Remove from MCP_SERVERS list in Lambda

---

## Key Naming Conventions

| Item | Convention | Example |
|------|------------|---------|
| Cloud Map Service Name | `{name}-server` | `currenttime-server` |
| ECS Service Name | `${EnvironmentName}-{name}` | `mcp-gateway-currenttime` |
| Container Name | `{name}-server` | `currenttime-server` |
| DNS Name (ClientAlias) | `{name}-server` | `currenttime-server` |
| Discovery Name | `{name}-server` | `currenttime-server` |
| proxy_pass_url | `http://{name}-server:{port}` | `http://currenttime-server:8000` |

**Critical**: The Cloud Map Service Name, DNS Name, and proxy_pass_url hostname must all match!

---

## Future Improvement: Automation

Consider creating a script that generates the CloudFormation snippets from a simple config:

```yaml
# mcp-servers.yaml
servers:
  - name: mynewserver
    port: 8000
    cpu: 512
    memory: 1024
    description: "My new MCP server"
    tags: ["demo"]
```

This could generate all the required CloudFormation resources automatically.

---

## Troubleshooting

### DNS Resolution Fails
- Verify Cloud Map service name matches the DNS name in ServiceConnect ClientAliases
- Check that ServiceRegistries is configured on the ECS service
- Verify the Discovery Service ARN export exists and is imported correctly

### Health Checks Fail
- Ensure the container port matches the health check port
- Check CloudWatch logs for the service
- Verify security group allows traffic on the service port

### Service Won't Start
- Check ECR repository exists and has the image
- Verify IAM roles have correct permissions
- Check CloudWatch logs for error messages
