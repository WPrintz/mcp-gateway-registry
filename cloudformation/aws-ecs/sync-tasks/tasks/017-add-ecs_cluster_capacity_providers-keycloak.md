# Task 017: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 81
- **Address**: `aws_ecs_cluster_capacity_providers.keycloak`
- **Type**: `aws_ecs_cluster_capacity_providers` → `UNKNOWN:aws_ecs_cluster_capacity_providers`

### TF Resource Block
```hcl
resource "aws_ecs_cluster_capacity_providers" "keycloak" {
  cluster_name       = aws_ecs_cluster.keycloak.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_ecs_cluster_capacity_providers` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_ecs_cluster_capacity_providers`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks