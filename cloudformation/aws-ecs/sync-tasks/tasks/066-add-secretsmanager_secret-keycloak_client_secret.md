# Task 066: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 44
- **Address**: `module.mcp-gateway.aws_secretsmanager_secret.keycloak_client_secret`
- **Type**: `aws_secretsmanager_secret` → `AWS::SecretsManager::Secret`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret" "keycloak_client_secret" {
  name        = "mcp-gateway-keycloak-client-secret"
  description = "Keycloak web client secret (updated by init-keycloak.sh after deployment)"
  tags        = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  KeycloakClientSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-keycloak_client_secret
```

## Instructions

1. Add the resource `KeycloakClientSecret` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks