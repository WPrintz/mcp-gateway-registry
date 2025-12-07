# Task 008: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 128
- **Address**: `aws_kms_alias.rds`
- **Type**: `aws_kms_alias` → `UNKNOWN:aws_kms_alias`

### TF Resource Block
```hcl
resource "aws_kms_alias" "rds" {
  name          = "alias/keycloak-rds"
  target_key_id = aws_kms_key.rds.key_id
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_kms_alias` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_kms_alias`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `Rds` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks