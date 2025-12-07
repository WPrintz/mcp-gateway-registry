# Task 047: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-alb.tf`
- **Line**: 25
- **Address**: `random_string.alb_tg_suffix`
- **Type**: `random_string` → `UNKNOWN:random_string`

### TF Resource Block
```hcl
resource "random_string" "alb_tg_suffix" {
  length  = 3
  special = false
  upper   = false
}
```

## ⚠️ Unknown CFN Type

The Terraform type `random_string` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `random_string`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `AlbTgSuffix` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks