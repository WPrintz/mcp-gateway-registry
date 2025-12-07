# Task 055: ADD Resource

**Action**: ADD
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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::CertificateManager::Certificate
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks