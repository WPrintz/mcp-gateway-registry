# Task 051: ADD Resource

**Action**: ADD
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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Registry:
    Type: AWS::CertificateManager::Certificate
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Registry` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks