# Task 005: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 88
- **Address**: `aws_db_subnet_group.keycloak`
- **Type**: `aws_db_subnet_group` → `AWS::RDS::DBSubnetGroup`

### TF Resource Block
```hcl
resource "aws_db_subnet_group" "keycloak" {
  name       = "keycloak-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = merge(
    local.common_tags,
    {
      Name = "keycloak-subnet-group"
    }
  )
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks