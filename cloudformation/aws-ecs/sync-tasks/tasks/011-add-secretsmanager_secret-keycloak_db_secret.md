# Task 011: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 173
- **Address**: `aws_secretsmanager_secret.keycloak_db_secret`
- **Type**: `aws_secretsmanager_secret` → `AWS::SecretsManager::Secret`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret" "keycloak_db_secret" {
  name                    = "keycloak/database"
  description             = "Keycloak database credentials"
  recovery_window_in_days = 7

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  KeycloakDbSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-keycloak_db_secret
```

## Instructions

1. Add the resource `KeycloakDbSecret` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks