# Task 012: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 121
- **Address**: `aws_iam_role_policy_attachment.keycloak_task_exec_role_policy`
- **Type**: `aws_iam_role_policy_attachment` → `AWS::IAM::ManagedPolicy`

### TF Resource Block
```hcl
resource "aws_iam_role_policy_attachment" "keycloak_task_exec_role_policy" {
  role       = aws_iam_role.keycloak_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  KeycloakTaskExecRolePolicy:
    Type: AWS::IAM::ManagedPolicy
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakTaskExecRolePolicy` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks