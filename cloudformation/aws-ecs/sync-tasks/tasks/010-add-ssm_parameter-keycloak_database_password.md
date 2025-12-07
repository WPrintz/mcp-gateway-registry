# Task 010: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 204
- **Address**: `aws_ssm_parameter.keycloak_database_password`
- **Type**: `aws_ssm_parameter` → `AWS::SSM::Parameter`

### TF Resource Block
```hcl
resource "aws_ssm_parameter" "keycloak_database_password" {
  name  = "/keycloak/database/password"
  type  = "SecureString"
  value = var.keycloak_database_password
  tags  = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  KeycloakDatabasePassword:
    Type: AWS::SSM::Parameter
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakDatabasePassword` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks