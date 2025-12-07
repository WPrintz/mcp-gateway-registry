# Task 027: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 111
- **Address**: `aws_security_group.keycloak_db`
- **Type**: `aws_security_group` → `AWS::EC2::SecurityGroup`

### TF Resource Block
```hcl
resource "aws_security_group" "keycloak_db" {
  name        = "keycloak-db"
  description = "Security group for Keycloak database"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "keycloak-db"
    }
  )
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  KeycloakDb:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Security group for Keycloak database
      VpcId: !Ref VPC  # TODO: verify reference
```

## Instructions

1. Add the resource `KeycloakDb` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks