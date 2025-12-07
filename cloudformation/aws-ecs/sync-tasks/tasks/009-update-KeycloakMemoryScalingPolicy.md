# Task 009: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:aws_appautoscaling_policy.keycloak_memory`
- **Line**: 0
- **Address**: `aws_appautoscaling_policy.keycloak_memory`
- **Type**: `aws_appautoscaling_policy` → `AWS::ApplicationAutoScaling::ScalingPolicy`

### TF Resource Block
```hcl
{
  "name": "keycloak-memory-autoscaling",
  "policy_type": "TargetTrackingScaling",
  "predictive_scaling_policy_configuration": [],
  "region": "us-east-1",
  "resource_id": "service/keycloak/keycloak",
  "scalable_dimension": "ecs:service:DesiredCount",
  "service_namespace": "ecs",
  "step_scaling_policy_configuration": [],
  "target_tracking_scaling_policy_configuration": [
    {
      "customized_metric_specification": [],
      "disable_scale_in": false,
      "predefined_metric_specification": [
        {
          "predefined_metric_type": "ECSServiceAverageMemoryUtilization",
          "resource_label": null
        }
      ],
      "scale_in_cooldown": null,
      "scale_out_cooldown": null,
      "target_value": 80
    }
  ]
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/services-stack.yaml`
- **Logical ID**: `KeycloakMemoryScalingPolicy`
- **Type**: `AWS::ApplicationAutoScaling::ScalingPolicy`

### CFN Resource Block
```yaml
  KeycloakMemoryScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Condition: EnableAutoScalingCondition
    Properties:
      PolicyName: !Sub ${EnvironmentName}-keycloak-memory-autoscaling
      PolicyType: TargetTrackingScaling
      ScalingTargetId: !Ref KeycloakScalableTarget
      TargetTrackingScalingPolicyConfiguration:
        PredefinedMetricSpecification:
          PredefinedMetricType: ECSServiceAverageMemoryUtilization
        TargetValue: 80.0

  # CurrentTime Auto Scaling
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment