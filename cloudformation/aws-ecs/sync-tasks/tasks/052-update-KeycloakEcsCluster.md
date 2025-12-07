# Task 052: UPDATE Resource

**Action**: UPDATE
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

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `KeycloakEcsCluster`
- **Type**: `AWS::ECS::Cluster`

### CFN Resource Block
```yaml
  KeycloakEcsCluster:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: !Sub ${EnvironmentName}-keycloak-cluster
      ClusterSettings:
        - Name: containerInsights
          Value: enabled
      CapacityProviders:
        - FARGATE
        - FARGATE_SPOT
      DefaultCapacityProviderStrategy:
        - CapacityProvider: FARGATE
          Weight: 1
          Base: 1
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-keycloak-cluster

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment