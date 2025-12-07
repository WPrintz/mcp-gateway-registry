# Task 071: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-dns.tf`
- **Line**: 12
- **Address**: `aws_acm_certificate.keycloak`
- **Type**: `aws_acm_certificate` → `AWS::CertificateManager::Certificate`

### TF Resource Block
```hcl
resource "aws_acm_certificate" "keycloak" {
  domain_name       = local.keycloak_domain
  validation_method = "DNS"

  tags = merge(
    local.common_tags,
    {
      Name = "keycloak-cert"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `KeycloakCertificate`
- **Type**: `AWS::CertificateManager::Certificate`

### CFN Resource Block
```yaml
  KeycloakCertificate:
    Type: AWS::CertificateManager::Certificate
    Condition: HasDnsConfig
    Properties:
      DomainName: !If
        - UseRegionalDomainsCondition
        - !Sub kc.${AWS::Region}.${BaseDomain}
        - !Sub kc.${BaseDomain}
      ValidationMethod: DNS
      DomainValidationOptions:
        - DomainName: !If
            - UseRegionalDomainsCondition
            - !Sub kc.${AWS::Region}.${BaseDomain}
            - !Sub kc.${BaseDomain}
          HostedZoneId: !Ref HostedZoneId
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-keycloak-cert

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment