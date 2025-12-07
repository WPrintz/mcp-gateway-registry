# Task 023: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 180
- **Address**: `aws_iam_role.keycloak_task_role`
- **Type**: `aws_iam_role` → `AWS::IAM::Role`

### TF Resource Block
```hcl
resource "aws_iam_role" "keycloak_task_role" {
  name = "keycloak-task-role-${var.aws_region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  KeycloakTaskRole:
    Type: AWS::IAM::Role
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakTaskRole` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks