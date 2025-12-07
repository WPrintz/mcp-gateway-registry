# Task 030: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-dns.tf`
- **Line**: 56
- **Address**: `aws_route53_record.keycloak`
- **Type**: `aws_route53_record` → `AWS::Route53::RecordSet`

### TF Resource Block
```hcl
resource "aws_route53_record" "keycloak" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.keycloak_domain
  type    = "A"

  alias {
    name                   = aws_lb.keycloak.dns_name
    zone_id                = aws_lb.keycloak.zone_id
    evaluate_target_health = true
  }
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::Route53::RecordSet
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks