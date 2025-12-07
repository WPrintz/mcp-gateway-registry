# Task 038: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 53
- **Address**: `aws_security_group_rule.keycloak_ecs_ingress_lb`
- **Type**: `aws_security_group_rule` → `UNKNOWN:aws_security_group_rule`

### TF Resource Block
```hcl
resource "aws_security_group_rule" "keycloak_ecs_ingress_lb" {
  description              = "Ingress from load balancer to Keycloak ECS task"
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak_ecs.id
  source_security_group_id = aws_security_group.keycloak_lb.id
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_security_group_rule` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_security_group_rule`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `KeycloakEcsIngressLb` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks