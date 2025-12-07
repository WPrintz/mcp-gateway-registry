# Task 051: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 181
- **Address**: `aws_secretsmanager_secret_version.keycloak_db_secret`
- **Type**: `aws_secretsmanager_secret_version` → `AWS::SecretsManager::Secret`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret_version" "keycloak_db_secret" {
  secret_id = aws_secretsmanager_secret.keycloak_db_secret.id
  secret_string = jsonencode({
    username = var.keycloak_database_username
    password = var.keycloak_database_password
  })
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/data-stack.yaml`
- **Logical ID**: `KeycloakClientSecret`
- **Type**: `AWS::SecretsManager::Secret`

### CFN Resource Block
```yaml
  KeycloakClientSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-keycloak-client-secret
      Description: Keycloak web client secret (updated by init script after deployment)
      SecretString: '{"client_secret": "placeholder-will-be-updated-by-init-script"}'
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-keycloak-client-secret

  # Keycloak M2M client secret (placeholder, updated by init script)
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment