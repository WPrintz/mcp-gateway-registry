# Task 013: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 190
- **Address**: `aws_ssm_parameter.keycloak_database_url`
- **Type**: `aws_ssm_parameter` → `AWS::SSM::Parameter`

### TF Resource Block
```hcl
resource "aws_ssm_parameter" "keycloak_database_url" {
  name  = "/keycloak/database/url"
  type  = "SecureString"
  value = "jdbc:mysql://${aws_rds_cluster.keycloak.endpoint}:3306/keycloak"
  tags  = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  KeycloakDatabaseUrl:
    Type: AWS::SSM::Parameter
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakDatabaseUrl` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks