# Task 010: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:aws_appautoscaling_target.keycloak`
- **Line**: 0
- **Address**: `aws_appautoscaling_target.keycloak`
- **Type**: `aws_appautoscaling_target` → `AWS::ApplicationAutoScaling::ScalableTarget`

### TF Resource Block
```hcl
{
  "max_capacity": 4,
  "min_capacity": 1,
  "region": "us-east-1",
  "resource_id": "service/keycloak/keycloak",
  "scalable_dimension": "ecs:service:DesiredCount",
  "service_namespace": "ecs"
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/services-stack.yaml`
- **Logical ID**: `KeycloakScalableTarget`
- **Type**: `AWS::ApplicationAutoScaling::ScalableTarget`

### CFN Resource Block
```yaml
  KeycloakScalableTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Condition: EnableAutoScalingCondition
    Properties:
      MaxCapacity: 4
      MinCapacity: 1
      ResourceId: !Sub service/${EnvironmentName}-keycloak-cluster/${EnvironmentName}-keycloak
      RoleARN: !Sub arn:aws:iam::${AWS::AccountId}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService
      ScalableDimension: ecs:service:DesiredCount
      ServiceNamespace: ecs
    DependsOn: KeycloakService

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment