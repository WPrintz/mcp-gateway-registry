# Task 014: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 160
- **Address**: `aws_iam_role_policy.keycloak_task_exec_logs_policy`
- **Type**: `aws_iam_role_policy` → `AWS::IAM::Policy`

### TF Resource Block
```hcl
resource "aws_iam_role_policy" "keycloak_task_exec_logs_policy" {
  name = "keycloak-task-exec-logs-policy"
  role = aws_iam_role.keycloak_task_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.keycloak.arn}:*"
      }
    ]
  })
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  KeycloakTaskExecLogsPolicy:
    Type: AWS::IAM::Policy
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakTaskExecLogsPolicy` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks