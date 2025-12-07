# Task 027: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 310
- **Address**: `aws_appautoscaling_target.keycloak`
- **Type**: `aws_appautoscaling_target` → `AWS::ApplicationAutoScaling::ScalableTarget`

### TF Resource Block
```hcl
resource "aws_appautoscaling_target" "keycloak" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.keycloak.name}/${aws_ecs_service.keycloak.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/services-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks