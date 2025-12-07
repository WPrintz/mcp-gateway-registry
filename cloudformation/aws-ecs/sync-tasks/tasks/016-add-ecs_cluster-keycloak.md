# Task 016: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 70
- **Address**: `aws_ecs_cluster.keycloak`
- **Type**: `aws_ecs_cluster` → `AWS::ECS::Cluster`

### TF Resource Block
```hcl
resource "aws_ecs_cluster" "keycloak" {
  name = "keycloak"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: !Sub ${EnvironmentName}-keycloak
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks