#!/usr/bin/env python3
"""
Generate CloudFormation snippets for adding new MCP servers.

Usage:
    python generate-mcp-server-cfn.py --name mynewserver --port 8000 --description "My server"

This generates the CloudFormation YAML snippets you need to add to:
- compute-stack.yaml (Cloud Map Discovery Service + Export)
- services-stack.yaml (Parameters, Log Group, Task Definition, Service)
"""

import argparse
import sys


def generate_compute_stack_snippet(name: str, port: int) -> str:
    """Generate compute-stack.yaml snippet for Cloud Map Discovery Service."""
    pascal_name = ''.join(word.capitalize() for word in name.split('-'))
    
    return f'''
# ============================================================================
# Add to compute-stack.yaml - Resources section (after ServiceDiscoveryNamespace)
# ============================================================================

  {pascal_name}DiscoveryService:
    Type: AWS::ServiceDiscovery::Service
    Properties:
      Name: {name}-server
      NamespaceId: !Ref ServiceDiscoveryNamespace
      Description: DNS service discovery for {pascal_name} MCP server
      DnsConfig:
        DnsRecords:
          - Type: A
            TTL: 10
        RoutingPolicy: MULTIVALUE
      HealthCheckCustomConfig:
        FailureThreshold: 1
      Tags:
        - Key: Name
          Value: !Sub ${{EnvironmentName}}-{name}-discovery

# ============================================================================
# Add to compute-stack.yaml - Outputs section
# ============================================================================

  {pascal_name}DiscoveryServiceArn:
    Description: {pascal_name} Cloud Map Discovery Service ARN
    Value: !GetAtt {pascal_name}DiscoveryService.Arn
    Export:
      Name: !Sub ${{EnvironmentName}}-{pascal_name}DiscoveryServiceArn
'''


def generate_services_stack_snippet(name: str, port: int, description: str, cpu: int = 512, memory: int = 1024) -> str:
    """Generate services-stack.yaml snippet for ECS Service."""
    pascal_name = ''.join(word.capitalize() for word in name.split('-'))
    upper_name = name.upper().replace('-', '_')
    
    return f'''
# ============================================================================
# Add to services-stack.yaml - Parameters section
# ============================================================================

  {pascal_name}ImageRepo:
    Type: String
    Default: 'mcp-gateway-{name}'
    Description: ECR repository name for {pascal_name} MCP server

  {pascal_name}ImageTag:
    Type: String
    Default: 'latest'
    Description: Image tag for {pascal_name} MCP server

# ============================================================================
# Add to services-stack.yaml - Resources section (Log Groups)
# ============================================================================

  {pascal_name}LogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub /ecs/${{EnvironmentName}}-{name}
      RetentionInDays: 30

# ============================================================================
# Add to services-stack.yaml - Resources section (Task Definitions)
# ============================================================================

  {pascal_name}TaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: !Sub ${{EnvironmentName}}-{name}
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      Cpu: '{cpu}'
      Memory: '{memory}'
      ExecutionRoleArn: !ImportValue
        Fn::Sub: ${{EnvironmentName}}-EcsTaskExecutionRoleArn
      TaskRoleArn: !ImportValue
        Fn::Sub: ${{EnvironmentName}}-EcsTaskRoleArn
      ContainerDefinitions:
        - Name: {name}-server
          Image: !Sub '${{AWS::AccountId}}.dkr.ecr.${{AWS::Region}}.amazonaws.com/${{{pascal_name}ImageRepo}}:${{{pascal_name}ImageTag}}'
          Essential: true
          PortMappings:
            - Name: {name}
              ContainerPort: {port}
              Protocol: tcp
          Environment:
            - Name: PORT
              Value: '{port}'
            - Name: MCP_TRANSPORT
              Value: streamable-http
          LogConfiguration:
            LogDriver: awslogs
            Options:
              awslogs-group: !Ref {pascal_name}LogGroup
              awslogs-region: !Ref AWS::Region
              awslogs-stream-prefix: ecs
          HealthCheck:
            Command:
              - CMD-SHELL
              - nc -z localhost {port} || exit 1
            Interval: 30
            Timeout: 5
            Retries: 3
            StartPeriod: 30
      Tags:
        - Key: Name
          Value: !Sub ${{EnvironmentName}}-{name}

# ============================================================================
# Add to services-stack.yaml - Resources section (ECS Services)
# ============================================================================

  {pascal_name}Service:
    Type: AWS::ECS::Service
    DependsOn: RegistryService
    Properties:
      ServiceName: !Sub ${{EnvironmentName}}-{name}
      Cluster: !ImportValue
        Fn::Sub: ${{EnvironmentName}}-MainEcsClusterArn
      TaskDefinition: !Ref {pascal_name}TaskDefinition
      DesiredCount: !Ref MinCapacity
      LaunchType: FARGATE
      EnableExecuteCommand: true
      NetworkConfiguration:
        AwsvpcConfiguration:
          AssignPublicIp: DISABLED
          SecurityGroups:
            - !ImportValue
              Fn::Sub: ${{EnvironmentName}}-McpServersSG
          Subnets: !Split
            - ','
            - !ImportValue
              Fn::Sub: ${{EnvironmentName}}-PrivateSubnets
      ServiceConnectConfiguration:
        Enabled: true
        Namespace: !ImportValue
          Fn::Sub: ${{EnvironmentName}}-ServiceDiscoveryNamespaceArn
        Services:
          - PortName: {name}
            ClientAliases:
              - Port: {port}
                DnsName: {name}-server
            DiscoveryName: {name}-server
      ServiceRegistries:
        - RegistryArn: !ImportValue
            Fn::Sub: ${{EnvironmentName}}-{pascal_name}DiscoveryServiceArn
          ContainerName: {name}-server
          ContainerPort: {port}
      Tags:
        - Key: Name
          Value: !Sub ${{EnvironmentName}}-{name}
'''


def generate_data_stack_snippet(name: str, port: int, description: str) -> str:
    """Generate data-stack.yaml snippet for server registration."""
    return f'''
# ============================================================================
# Add to data-stack.yaml - MCP_SERVERS list in McpServerRegistrationLambda
# ============================================================================

              {{
                  "server_name": "{name}-server",
                  "path": "/mcp/{name}",
                  "description": "{description}",
                  "tags": ["mcp", "server"],
                  "proxy_pass_url": "http://{name}-server:{port}",
                  "is_python": True,
                  "num_tools": 0,
                  "tool_list": []
              }},
'''


def main():
    parser = argparse.ArgumentParser(
        description='Generate CloudFormation snippets for new MCP servers',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
    python generate-mcp-server-cfn.py --name weather --port 8000 --description "Weather MCP server"
    python generate-mcp-server-cfn.py --name calculator --port 8001 --cpu 256 --memory 512
        '''
    )
    parser.add_argument('--name', required=True, help='Server name (lowercase, hyphens ok)')
    parser.add_argument('--port', type=int, required=True, help='Container port')
    parser.add_argument('--description', default='MCP server', help='Server description')
    parser.add_argument('--cpu', type=int, default=512, help='CPU units (default: 512)')
    parser.add_argument('--memory', type=int, default=1024, help='Memory MB (default: 1024)')
    parser.add_argument('--output', '-o', help='Output file (default: stdout)')
    
    args = parser.parse_args()
    
    # Validate name
    if not args.name.replace('-', '').isalnum():
        print("Error: Name must be alphanumeric with optional hyphens", file=sys.stderr)
        sys.exit(1)
    
    output = []
    output.append("=" * 80)
    output.append(f"CloudFormation snippets for MCP server: {args.name}")
    output.append("=" * 80)
    output.append("")
    output.append(generate_compute_stack_snippet(args.name, args.port))
    output.append(generate_services_stack_snippet(args.name, args.port, args.description, args.cpu, args.memory))
    output.append(generate_data_stack_snippet(args.name, args.port, args.description))
    
    result = '\n'.join(output)
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(result)
        print(f"Output written to {args.output}")
    else:
        print(result)


if __name__ == '__main__':
    main()
