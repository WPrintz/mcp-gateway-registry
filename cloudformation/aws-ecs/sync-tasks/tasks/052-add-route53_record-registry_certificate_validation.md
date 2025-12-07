# Task 052: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/registry-dns.tf`
- **Line**: 33
- **Address**: `aws_route53_record.registry_certificate_validation`
- **Type**: `aws_route53_record` → `AWS::Route53::RecordSet`

### TF Resource Block
```hcl
resource "aws_route53_record" "registry_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.registry.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.registry_root.zone_id
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/network-stack.yaml`

```yaml
  RegistryCertificateValidation:
    Type: AWS::Route53::RecordSet
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `RegistryCertificateValidation` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks