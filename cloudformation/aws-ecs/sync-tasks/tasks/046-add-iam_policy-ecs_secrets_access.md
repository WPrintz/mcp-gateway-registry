# Task 046: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/iam.tf`
- **Line**: 4
- **Address**: `module.mcp-gateway.aws_iam_policy.ecs_secrets_access`
- **Type**: `aws_iam_policy` → `AWS::IAM::ManagedPolicy`

### TF Resource Block
```hcl
resource "aws_iam_policy" "ecs_secrets_access" {
  name_prefix = "${local.name_prefix}-ecs-secrets-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.secret_key.arn,
          aws_secretsmanager_secret.admin_password.arn,
          aws_secretsmanager_secret.keycloak_client_secret.arn,
          aws_secretsmanager_secret.keycloak_m2m_client_secret.arn
        ]
      }
    ]
  })

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  EcsSecretsAccess:
    Type: AWS::IAM::ManagedPolicy
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `EcsSecretsAccess` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks