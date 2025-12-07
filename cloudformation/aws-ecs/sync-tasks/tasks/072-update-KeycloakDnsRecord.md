# Task 072: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-dns.tf`
- **Line**: 29
- **Address**: `aws_route53_record.keycloak_certificate_validation`
- **Type**: `aws_route53_record` → `AWS::Route53::RecordSet`

### TF Resource Block
```hcl
resource "aws_route53_record" "keycloak_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.keycloak.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.root.zone_id
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `KeycloakDnsRecord`
- **Type**: `AWS::Route53::RecordSet`

### CFN Resource Block
```yaml
  KeycloakDnsRecord:
    Type: AWS::Route53::RecordSet
    Condition: HasDnsConfig
    Properties:
      HostedZoneId: !Ref HostedZoneId
      Name: !If
        - UseRegionalDomainsCondition
        - !Sub kc.${AWS::Region}.${BaseDomain}
        - !Sub kc.${BaseDomain}
      Type: A
      AliasTarget:
        DNSName: !GetAtt KeycloakAlb.DNSName
        HostedZoneId: !GetAtt KeycloakAlb.CanonicalHostedZoneID
        EvaluateTargetHealth: true

  #============================================================================
  # CloudFront Distribution for Keycloak HTTPS (no custom domain required)
  # Provides HTTPS via *.cloudfront.net certificate when Route53 is not available
  #============================================================================
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment