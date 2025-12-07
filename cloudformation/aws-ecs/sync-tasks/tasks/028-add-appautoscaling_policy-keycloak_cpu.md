# Task 028: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 321
- **Address**: `aws_appautoscaling_policy.keycloak_cpu`
- **Type**: `aws_appautoscaling_policy` → `AWS::ApplicationAutoScaling::ScalingPolicy`

### TF Resource Block
```hcl
resource "aws_appautoscaling_policy" "keycloak_cpu" {
  name               = "keycloak-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.keycloak.resource_id
  scalable_dimension = aws_appautoscaling_target.keycloak.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keycloak.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/services-stack.yaml`

```yaml
  KeycloakCpu:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakCpu` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks