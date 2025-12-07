# Task 053: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 93
- **Address**: `aws_cloudwatch_log_group.keycloak`
- **Type**: `aws_cloudwatch_log_group` → `AWS::Logs::LogGroup`

### TF Resource Block
```hcl
resource "aws_cloudwatch_log_group" "keycloak" {
  name              = "/ecs/keycloak"
  retention_in_days = 7

  tags = local.common_tags
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/services-stack.yaml`
- **Logical ID**: `KeycloakLogGroup`
- **Type**: `AWS::Logs::LogGroup`

### CFN Resource Block
```yaml
  KeycloakLogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub /ecs/${EnvironmentName}-keycloak
      RetentionInDays: 7

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment