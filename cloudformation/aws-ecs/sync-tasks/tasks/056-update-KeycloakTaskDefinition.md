# Task 056: UPDATE Resource

**Action**: UPDATE
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

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/services-stack.yaml`
- **Logical ID**: `KeycloakTaskDefinition`
- **Type**: `AWS::ECS::TaskDefinition`

### CFN Resource Block
```yaml
  KeycloakTaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: !Sub ${EnvironmentName}-keycloak
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      Cpu: !Ref KeycloakCpu
      Memory: !Ref KeycloakMemory
      ExecutionRoleArn: !ImportValue
        Fn::Sub: ${EnvironmentName}-KeycloakTaskExecutionRoleArn
      TaskRoleArn: !ImportValue
        Fn::Sub: ${EnvironmentName}-EcsTaskRoleArn
      ContainerDefinitions:
        - Name: keycloak
          Image: !Sub '${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/${KeycloakImageRepo}:${KeycloakImageTag}'
          Essential: true
          ReadonlyRootFilesystem: false
          PortMappings:
            - Name: keycloak
              ContainerPort: 8080
              HostPort: 8080
              Protocol: tcp
            - Name: keycloak-management
              ContainerPort: 9000
              HostPort: 9000
              Protocol: tcp
          Environment:
            # Matching Terraform keycloak_container_env exactly
            - Name: AWS_REGION
              Value: !Ref AWS::Region
            - Name: KC_PROXY
              Value: edge
            - Name: KC_PROXY_ADDRESS_FORWARDING
              Value: 'true'
            - Name: KC_HOSTNAME
              Value: !ImportValue
                Fn::Sub: ${EnvironmentName}-KeycloakCloudFrontDomain
            - Name: KC_HOSTNAME_STRICT
              Value: 'false'
            - Name: KC_HOSTNAME_STRICT_HTTPS
              Value: 'true'
            - Name: KC_HEALTH_ENABLED
              Value: 'true'
            - Name: KC_METRICS_ENABLED
              Value: 'true'
            - Name: KEYCLOAK_LOGLEVEL
              Value: !Ref KeycloakLogLevel
          Secrets:
            # Matching Terraform keycloak_container_secrets exactly (using SSM)
            - Name: KEYCLOAK_ADMIN
              ValueFrom: !ImportValue
                Fn::Sub: ${EnvironmentName}-SsmKeycloakAdminArn
            - Name: KEYCLOA
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment