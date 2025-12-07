# Task 064: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 32
- **Address**: `module.mcp-gateway.aws_secretsmanager_secret.admin_password`
- **Type**: `aws_secretsmanager_secret` → `AWS::SecretsManager::Secret`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret" "admin_password" {
  name_prefix = "${local.name_prefix}-admin-password-"
  description = "Admin password for MCP Gateway Registry"
  tags        = local.common_tags
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