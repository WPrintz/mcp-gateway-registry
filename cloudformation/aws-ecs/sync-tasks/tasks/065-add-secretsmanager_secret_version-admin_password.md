# Task 065: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/secrets.tf`
- **Line**: 38
- **Address**: `module.mcp-gateway.aws_secretsmanager_secret_version.admin_password`
- **Type**: `aws_secretsmanager_secret_version` → `UNKNOWN:aws_secretsmanager_secret_version`

### TF Resource Block
```hcl
resource "aws_secretsmanager_secret_version" "admin_password" {
  secret_id     = aws_secretsmanager_secret.admin_password.id
  secret_string = random_password.admin_password.result
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_secretsmanager_secret_version` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_secretsmanager_secret_version`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `AdminPassword` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks