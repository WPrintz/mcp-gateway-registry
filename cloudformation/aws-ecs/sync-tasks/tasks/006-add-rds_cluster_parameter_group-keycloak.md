# Task 006: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 101
- **Address**: `aws_rds_cluster_parameter_group.keycloak`
- **Type**: `aws_rds_cluster_parameter_group` → `AWS::RDS::DBClusterParameterGroup`

### TF Resource Block
```hcl
resource "aws_rds_cluster_parameter_group" "keycloak" {
  family      = "aurora-mysql8.0"
  name        = "keycloak-params"
  description = "Keycloak Aurora MySQL parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::RDS::DBClusterParameterGroup
    Properties:
      DBClusterIdentifier: !Sub ${EnvironmentName}-keycloak
      Engine: aurora-mysql
      MasterUsername: !Ref KeycloakDatabaseUsername
      MasterUserPassword: !Ref KeycloakDatabasePassword
      DBSubnetGroupName: !Ref DbSubnetGroup
      VpcSecurityGroupIds:
        - !Ref DatabaseSG
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks