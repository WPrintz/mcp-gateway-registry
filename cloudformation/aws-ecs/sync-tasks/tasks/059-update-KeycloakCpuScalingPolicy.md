# Task 059: UPDATE Resource

**Action**: UPDATE
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

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/services-stack.yaml`
- **Logical ID**: `KeycloakCpuScalingPolicy`
- **Type**: `AWS::ApplicationAutoScaling::ScalingPolicy`

### CFN Resource Block
```yaml
  KeycloakCpuScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Condition: EnableAutoScalingCondition
    Properties:
      PolicyName: !Sub ${EnvironmentName}-keycloak-cpu-autoscaling
      PolicyType: TargetTrackingScaling
      ScalingTargetId: !Ref KeycloakScalableTarget
      TargetTrackingScalingPolicyConfiguration:
        PredefinedMetricSpecification:
          PredefinedMetricType: ECSServiceAverageCPUUtilization
        TargetValue: 70.0

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment