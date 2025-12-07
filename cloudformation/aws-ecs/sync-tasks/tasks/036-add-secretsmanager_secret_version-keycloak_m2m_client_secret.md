# Task 036: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 67
- **Address**: `module.mcp-gateway.aws_secretsmanager_secret_version.keycloak_m2m_client_secret`
- **Type**: `aws_secretsmanager_secret_version` → `AWS::SecretsManager::Secret`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret_version" "keycloak_m2m_client_secret" {
  secret_id = aws_secretsmanager_secret.keycloak_m2m_client_secret.id
  secret_string = jsonencode({
    client_secret = "placeholder-will-be-updated-by-init-script"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  KeycloakM2mClientSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-keycloak_m2m_client_secret
```

## Instructions

1. Add the resource `KeycloakM2mClientSecret` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks