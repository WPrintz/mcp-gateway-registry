# Task 007: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 120
- **Address**: `aws_kms_key.rds`
- **Type**: `aws_kms_key` → `AWS::KMS::Key`

### TF Resource Block
```hcl
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  Rds:
    Type: AWS::KMS::Key
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Rds` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks