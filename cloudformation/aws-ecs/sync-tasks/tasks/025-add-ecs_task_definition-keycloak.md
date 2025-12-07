# Task 025: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 222
- **Address**: `aws_ecs_task_definition.keycloak`
- **Type**: `aws_ecs_task_definition` → `AWS::ECS::TaskDefinition`

### TF Resource Block
```hcl
resource "aws_ecs_task_definition" "keycloak" {
  family                   = "keycloak"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.keycloak_task_exec_role.arn
  task_role_arn            = aws_iam_role.keycloak_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "keycloak"
      image     = "${aws_ecr_repository.keycloak.repository_url}:latest"
      essential = true

      portMappings = [
        {
          name          = "keycloak"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        },
        {
          name          = "keycloak-management"
          containerPort = 9000
          hostPort      = 9000
          protocol      = "tcp"
        }
      ]

      environment = local.keycloak_container_env

      secrets = local.keycloak_container_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.keycloak.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      readonlyRootFilesystem = false

      healthCheck = {
        command     = ["CMD-SHELL", "exit 0"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/services-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::ECS::TaskDefinition
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks