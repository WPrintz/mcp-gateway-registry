# Task 078: UPDATE Resource

**Action**: UPDATE
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

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/data-stack.yaml`
- **Logical ID**: `KeycloakM2MClientSecret`
- **Type**: `AWS::SecretsManager::Secret`

### CFN Resource Block
```yaml
  KeycloakM2MClientSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${EnvironmentName}-keycloak-m2m-client-secret
      Description: Keycloak M2M client secret (updated by init script after deployment)
      SecretString: '{"client_secret": "placeholder-will-be-updated-by-init-script"}'
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-keycloak-m2m-client-secret

  #============================================================================
  # Aurora Serverless v2 Database
  #============================================================================
  
  # DB Subnet Group
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment