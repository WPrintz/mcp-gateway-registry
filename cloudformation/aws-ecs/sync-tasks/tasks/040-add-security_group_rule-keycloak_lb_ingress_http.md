# Task 040: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 78
- **Address**: `aws_security_group_rule.keycloak_lb_ingress_http`
- **Type**: `aws_security_group_rule` → `UNKNOWN:aws_security_group_rule`

### TF Resource Block
```hcl
resource "aws_security_group_rule" "keycloak_lb_ingress_http" {
  description       = "Ingress from internet to load balancer (HTTP)"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.keycloak_lb.id
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_security_group_rule` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_security_group_rule`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `KeycloakLbIngressHttp` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks