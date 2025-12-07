# Task 081: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/iam.tf`
- **Line**: 62
- **Address**: `module.mcp-gateway.aws_iam_policy.ecs_exec_task`
- **Type**: `aws_iam_policy` → `UNKNOWN:aws_iam_policy`

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

## ⚠️ Unknown CFN Type

The Terraform type `aws_iam_policy` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_iam_policy`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `EcsExecTask` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks