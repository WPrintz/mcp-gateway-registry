# Task 069: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/registry-dns.tf`
- **Line**: 15
- **Address**: `aws_acm_certificate.registry`
- **Type**: `aws_acm_certificate` → `AWS::CertificateManager::Certificate`

### TF Resource Block
```hcl
resource "aws_acm_certificate" "registry" {
  domain_name       = "registry.${local.root_domain}"
  validation_method = "DNS"

  tags = merge(
    local.common_tags,
    {
      Name      = "registry-cert"
      Component = "registry"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `RegistryCertificate`
- **Type**: `AWS::CertificateManager::Certificate`

### CFN Resource Block
```yaml
  RegistryCertificate:
    Type: AWS::CertificateManager::Certificate
    Condition: HasDnsConfig
    Properties:
      DomainName: !If
        - UseRegionalDomainsCondition
        - !Sub registry.${AWS::Region}.${BaseDomain}
        - !Sub registry.${BaseDomain}
      ValidationMethod: DNS
      DomainValidationOptions:
        - DomainName: !If
            - UseRegionalDomainsCondition
            - !Sub registry.${AWS::Region}.${BaseDomain}
            - !Sub registry.${BaseDomain}
          HostedZoneId: !Ref HostedZoneId
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-registry-cert

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment