# Task 026: ADD Resource

**Action**: ADD
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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/services-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::ECS::Service
    Properties:
      ServiceName: !Sub ${EnvironmentName}-keycloak
      Cluster: !Ref MainEcsCluster  # TODO: verify reference
      TaskDefinition: !Ref TODO_TaskDefinition
      DesiredCount: 1
      LaunchType: FARGATE
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks