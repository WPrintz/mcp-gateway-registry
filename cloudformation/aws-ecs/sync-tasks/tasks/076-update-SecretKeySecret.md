# Task 076: UPDATE Resource

**Action**: UPDATE
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

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/data-stack.yaml`
- **Logical ID**: `SecretKeySecret`
- **Type**: `AWS::SecretsManager::Secret`

### CFN Resource Block
```yaml
  SecretKeySecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-secret-key
      Description: Secret key for MCP Gateway Registry
      GenerateSecretString:
        SecretStringTemplate: '{}'
        GenerateStringKey: secret_key
        PasswordLength: 64
        ExcludeCharacters: '"@/\'
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-secret-key

  # Admin password secret
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment