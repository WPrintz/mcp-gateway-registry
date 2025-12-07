# Task 060: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 5
- **Address**: `module.mcp-gateway.random_password.secret_key`
- **Type**: `random_password` → `UNKNOWN:random_password`

### TF Resource Block
```hcl
resource "random_password" "secret_key" {
  length  = 64
  special = true
}
```

## ⚠️ Unknown CFN Type

The Terraform type `random_password` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `random_password`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `SecretKey` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks