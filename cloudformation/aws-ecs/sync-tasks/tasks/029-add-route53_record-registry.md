# Task 029: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/registry-dns.tf`
- **Line**: 62
- **Address**: `aws_route53_record.registry`
- **Type**: `aws_route53_record` → `AWS::Route53::RecordSet`

### TF Resource Block
```hcl
resource "aws_route53_record" "registry" {
  zone_id = data.aws_route53_zone.registry_root.zone_id
  name    = "registry.${local.root_domain}"
  type    = "A"

  alias {
    name                   = module.mcp_gateway.alb_dns_name
    zone_id                = module.mcp_gateway.alb_zone_id
    evaluate_target_health = true
  }
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  Registry:
    Type: AWS::Route53::RecordSet
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Registry` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks