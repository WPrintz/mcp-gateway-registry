# Task 057: UPDATE Resource

**Action**: UPDATE
**Priority**: HIGH

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 281
- **Address**: `aws_ecs_service.keycloak`
- **Type**: `aws_ecs_service` → `AWS::ECS::Service`

### TF Resource Block
```hcl
resource "aws_ecs_service" "keycloak" {
  name            = "keycloak"
  cluster         = aws_ecs_cluster.keycloak.id
  task_definition = aws_ecs_task_definition.keycloak.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.keycloak_ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak.arn
    container_name   = "keycloak"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.keycloak_https,
    aws_iam_role_policy.keycloak_task_exec_ssm_policy,
    aws_iam_role_policy.keycloak_task_exec_logs_policy
  ]

  tags = local.common_tags
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/services-stack.yaml`
- **Logical ID**: `KeycloakService`
- **Type**: `AWS::ECS::Service`

### CFN Resource Block
```yaml
  KeycloakService:
    Type: AWS::ECS::Service
    Properties:
      ServiceName: !Sub ${EnvironmentName}-keycloak
      Cluster: !ImportValue
        Fn::Sub: ${EnvironmentName}-KeycloakEcsClusterArn
      TaskDefinition: !Ref KeycloakTaskDefinition
      DesiredCount: 1
      LaunchType: FARGATE
      EnableExecuteCommand: true
      NetworkConfiguration:
        AwsvpcConfiguration:
          AssignPublicIp: DISABLED
          SecurityGroups:
            - !ImportValue
              Fn::Sub: ${EnvironmentName}-KeycloakEcsSG
          Subnets: !Split
            - ','
            - !ImportValue
              Fn::Sub: ${EnvironmentName}-PrivateSubnets
      LoadBalancers:
        - ContainerName: keycloak
          ContainerPort: 8080
          TargetGroupArn: !ImportValue
            Fn::Sub: ${EnvironmentName}-KeycloakTargetGroupArn
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-keycloak

  # CurrentTime MCP Server Service
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment