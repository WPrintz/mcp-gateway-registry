# Task 048: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/iam.tf`
- **Line**: 62
- **Address**: `module.mcp-gateway.aws_iam_policy.ecs_exec_task`
- **Type**: `aws_iam_policy` → `AWS::IAM::ManagedPolicy`

### TF Resource Block
```hcl
resource "aws_iam_policy" "ecs_exec_task" {
  name_prefix = "${local.name_prefix}-ecs-exec-task-"

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

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  EcsExecTask:
    Type: AWS::IAM::ManagedPolicy
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `EcsExecTask` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks