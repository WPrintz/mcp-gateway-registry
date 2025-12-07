# Task 077: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 27
- **Address**: `module.mcp-gateway.aws_secretsmanager_secret_version.secret_key`
- **Type**: `aws_secretsmanager_secret_version` → `AWS::SecretsManager::Secret`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret_version" "secret_key" {
  secret_id     = aws_secretsmanager_secret.secret_key.id
  secret_string = random_password.secret_key.result
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/data-stack.yaml`
- **Logical ID**: `AdminPasswordSecret`
- **Type**: `AWS::SecretsManager::Secret`

### CFN Resource Block
```yaml
  AdminPasswordSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-admin-password
      Description: Admin password for MCP Gateway Registry
      GenerateSecretString:
        SecretStringTemplate: '{}'
        GenerateStringKey: admin_password
        PasswordLength: 32
        RequireEachIncludedType: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-admin-password

  # Keycloak client secret (placeholder, updated by init script)
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment