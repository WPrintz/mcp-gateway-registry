# Task 062: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 21
- **Address**: `module.mcp-gateway.aws_secretsmanager_secret.secret_key`
- **Type**: `aws_secretsmanager_secret` → `AWS::SecretsManager::Secret`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret" "secret_key" {
  name_prefix = "${local.name_prefix}-secret-key-"
  description = "Secret key for MCP Gateway Registry"
  tags        = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  SecretKey:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-secret_key
```

## Instructions

1. Add the resource `SecretKey` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks