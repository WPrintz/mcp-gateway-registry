# Task 033: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecr.tf`
- **Line**: 22
- **Address**: `aws_ecr_lifecycle_policy.keycloak`
- **Type**: `aws_ecr_lifecycle_policy` → `UNKNOWN:aws_ecr_lifecycle_policy`

### TF Resource Block
```hcl
resource "aws_ecr_lifecycle_policy" "keycloak" {
  repository = aws_ecr_repository.keycloak.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 10
        description  = "Keep last 10 git SHA tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 20
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_ecr_lifecycle_policy` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_ecr_lifecycle_policy`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks