# Task 018: ADD Resource

**Action**: ADD
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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::Logs::LogGroup
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks