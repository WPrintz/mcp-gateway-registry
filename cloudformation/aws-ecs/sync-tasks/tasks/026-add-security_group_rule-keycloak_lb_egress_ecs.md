# Task 026: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 100
- **Address**: `aws_security_group_rule.keycloak_lb_egress_ecs`
- **Type**: `aws_security_group_rule` → `AWS::EC2::SecurityGroupIngress`

### TF Resource Block
```hcl
resource "aws_security_group_rule" "keycloak_lb_egress_ecs" {
  description              = "Egress from load balancer to Keycloak ECS task"
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak_lb.id
  source_security_group_id = aws_security_group.keycloak_ecs.id
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  KeycloakLbEgressEcs:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupDescription: Egress from load balancer to Keycloak ECS task
      VpcId: !Ref VPC  # TODO: verify reference
```

## Instructions

1. Add the resource `KeycloakLbEgressEcs` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks