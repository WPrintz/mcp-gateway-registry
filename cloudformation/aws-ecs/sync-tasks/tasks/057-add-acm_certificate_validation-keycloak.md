# Task 057: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-dns.tf`
- **Line**: 47
- **Address**: `aws_acm_certificate_validation.keycloak`
- **Type**: `aws_acm_certificate_validation` → `UNKNOWN:aws_acm_certificate_validation`

### TF Resource Block
```hcl
resource "aws_acm_certificate_validation" "keycloak" {
  certificate_arn = aws_acm_certificate.keycloak.arn
  timeouts {
    create = "5m"
  }
  validation_record_fqdns = [for record in aws_route53_record.keycloak_certificate_validation : record.fqdn]
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_acm_certificate_validation` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_acm_certificate_validation`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks