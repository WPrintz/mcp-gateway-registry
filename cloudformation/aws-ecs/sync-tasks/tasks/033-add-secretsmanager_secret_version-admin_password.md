# Task 033: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 38
- **Address**: `module.mcp-gateway.aws_secretsmanager_secret_version.admin_password`
- **Type**: `aws_secretsmanager_secret_version` → `AWS::SecretsManager::Secret`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret_version" "admin_password" {
  secret_id     = aws_secretsmanager_secret.admin_password.id
  secret_string = random_password.admin_password.result
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  AdminPassword:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-admin_password
```

## Instructions

1. Add the resource `AdminPassword` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks