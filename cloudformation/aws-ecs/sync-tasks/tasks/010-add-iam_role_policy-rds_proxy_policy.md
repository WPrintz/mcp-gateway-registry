# Task 010: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 154
- **Address**: `aws_iam_role_policy.rds_proxy_policy`
- **Type**: `aws_iam_role_policy` → `UNKNOWN:aws_iam_role_policy`

### TF Resource Block
```hcl
resource "aws_iam_role_policy" "rds_proxy_policy" {
  name = "keycloak-rds-proxy-policy"
  role = aws_iam_role.rds_proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.keycloak_db_secret.arn
      }
    ]
  })
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_iam_role_policy` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_iam_role_policy`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `RdsProxyPolicy` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks