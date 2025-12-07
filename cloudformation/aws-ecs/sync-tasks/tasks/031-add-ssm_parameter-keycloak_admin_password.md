# Task 031: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 360
- **Address**: `aws_ssm_parameter.keycloak_admin_password`
- **Type**: `aws_ssm_parameter` → `AWS::SSM::Parameter`

### TF Resource Block
```hcl
resource "aws_ssm_parameter" "keycloak_admin_password" {
  name  = "/keycloak/admin_password"
  type  = "SecureString"
  value = var.keycloak_admin_password
  tags  = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  KeycloakAdminPassword:
    Type: AWS::SSM::Parameter
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakAdminPassword` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks