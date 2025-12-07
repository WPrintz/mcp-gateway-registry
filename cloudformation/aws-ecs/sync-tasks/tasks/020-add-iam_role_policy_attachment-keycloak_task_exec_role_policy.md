# Task 020: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 121
- **Address**: `aws_iam_role_policy_attachment.keycloak_task_exec_role_policy`
- **Type**: `aws_iam_role_policy_attachment` → `UNKNOWN:aws_iam_role_policy_attachment`

### TF Resource Block
```hcl
resource "aws_iam_role_policy_attachment" "keycloak_task_exec_role_policy" {
  role       = aws_iam_role.keycloak_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_iam_role_policy_attachment` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_iam_role_policy_attachment`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `KeycloakTaskExecRolePolicy` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks