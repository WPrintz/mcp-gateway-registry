# Task 024: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 200
- **Address**: `aws_iam_role_policy.keycloak_task_ssm_policy`
- **Type**: `aws_iam_role_policy` → `UNKNOWN:aws_iam_role_policy`

### TF Resource Block
```hcl
resource "aws_iam_role_policy" "keycloak_task_ssm_policy" {
  name = "keycloak-task-ssm-policy"
  role = aws_iam_role.keycloak_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
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

1. Add the resource `KeycloakTaskSsmPolicy` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks