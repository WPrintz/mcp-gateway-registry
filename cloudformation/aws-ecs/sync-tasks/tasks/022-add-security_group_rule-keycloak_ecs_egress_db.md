# Task 022: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 42
- **Address**: `aws_security_group_rule.keycloak_ecs_egress_db`
- **Type**: `aws_security_group_rule` → `AWS::EC2::SecurityGroupIngress`

### TF Resource Block
```hcl
resource "aws_security_group_rule" "keycloak_ecs_egress_db" {
  description              = "Egress from Keycloak ECS task to database"
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak_ecs.id
  source_security_group_id = aws_security_group.keycloak_db.id
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  KeycloakEcsEgressDb:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupDescription: Egress from Keycloak ECS task to database
      VpcId: !Ref VPC  # TODO: verify reference
```

## Instructions

1. Add the resource `KeycloakEcsEgressDb` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks