# Task 013: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 127
- **Address**: `aws_iam_role_policy.keycloak_task_exec_ssm_policy`
- **Type**: `aws_iam_role_policy` → `AWS::IAM::Policy`

### TF Resource Block
```hcl
resource "aws_iam_role_policy" "keycloak_task_exec_ssm_policy" {
  name = "keycloak-task-exec-ssm-policy"
  role = aws_iam_role.keycloak_task_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.keycloak_admin.arn,
          aws_ssm_parameter.keycloak_admin_password.arn,
          aws_ssm_parameter.keycloak_database_url.arn,
          aws_ssm_parameter.keycloak_database_username.arn,
          aws_ssm_parameter.keycloak_database_password.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  KeycloakTaskExecSsmPolicy:
    Type: AWS::IAM::Policy
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakTaskExecSsmPolicy` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks