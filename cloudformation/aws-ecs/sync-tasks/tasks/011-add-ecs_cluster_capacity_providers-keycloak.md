# Task 011: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 81
- **Address**: `aws_ecs_cluster_capacity_providers.keycloak`
- **Type**: `aws_ecs_cluster_capacity_providers` → `AWS::ECS::ClusterCapacityProviderAssociations`

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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::ECS::ClusterCapacityProviderAssociations
    Properties:
      ClusterName: !Sub ${EnvironmentName}-keycloak
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks