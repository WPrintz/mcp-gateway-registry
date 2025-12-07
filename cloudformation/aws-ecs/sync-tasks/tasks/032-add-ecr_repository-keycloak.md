# Task 032: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecr.tf`
- **Line**: 5
- **Address**: `aws_ecr_repository.keycloak`
- **Type**: `aws_ecr_repository` → `AWS::ECR::Repository`

### TF Resource Block
```hcl
resource "aws_ecr_repository" "keycloak" {
  name                 = "keycloak"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "keycloak"
    }
  )
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::ECR::Repository
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks