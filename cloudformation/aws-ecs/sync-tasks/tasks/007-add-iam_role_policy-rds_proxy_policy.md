# Task 007: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 154
- **Address**: `aws_iam_role_policy.rds_proxy_policy`
- **Type**: `aws_iam_role_policy` → `AWS::IAM::Policy`

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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  RdsProxyPolicy:
    Type: AWS::IAM::Policy
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `RdsProxyPolicy` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks