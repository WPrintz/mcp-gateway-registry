# Task 012: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 181
- **Address**: `aws_secretsmanager_secret_version.keycloak_db_secret`
- **Type**: `aws_secretsmanager_secret_version` → `UNKNOWN:aws_secretsmanager_secret_version`

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

## ⚠️ Unknown CFN Type

The Terraform type `aws_secretsmanager_secret_version` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_secretsmanager_secret_version`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `KeycloakDbSecret` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks