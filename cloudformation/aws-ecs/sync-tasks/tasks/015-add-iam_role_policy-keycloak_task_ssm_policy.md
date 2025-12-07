# Task 015: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 200
- **Address**: `aws_iam_role_policy.keycloak_task_ssm_policy`
- **Type**: `aws_iam_role_policy` → `AWS::IAM::Policy`

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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  KeycloakTaskSsmPolicy:
    Type: AWS::IAM::Policy
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakTaskSsmPolicy` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks