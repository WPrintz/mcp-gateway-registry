# Task 021: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 31
- **Address**: `aws_security_group_rule.keycloak_ecs_egress_dns`
- **Type**: `aws_security_group_rule` → `AWS::EC2::SecurityGroupIngress`

### TF Resource Block
```hcl
resource "aws_security_group_rule" "keycloak_ecs_egress_dns" {
  description       = "Egress from Keycloak ECS task for DNS"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.keycloak_ecs.id
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  KeycloakEcsEgressDns:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupDescription: Egress from Keycloak ECS task for DNS
      VpcId: !Ref VPC  # TODO: verify reference
```

## Instructions

1. Add the resource `KeycloakEcsEgressDns` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks