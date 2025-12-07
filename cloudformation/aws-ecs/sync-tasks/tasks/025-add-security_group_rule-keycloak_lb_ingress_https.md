# Task 025: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 89
- **Address**: `aws_security_group_rule.keycloak_lb_ingress_https`
- **Type**: `aws_security_group_rule` → `AWS::EC2::SecurityGroupIngress`

### TF Resource Block
```hcl
resource "aws_security_group_rule" "keycloak_lb_ingress_https" {
  description       = "Ingress from internet to load balancer (HTTPS)"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.keycloak_lb.id
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  KeycloakLbIngressHttps:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupDescription: Ingress from internet to load balancer (HTTPS)
      VpcId: !Ref VPC  # TODO: verify reference
```

## Instructions

1. Add the resource `KeycloakLbIngressHttps` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks