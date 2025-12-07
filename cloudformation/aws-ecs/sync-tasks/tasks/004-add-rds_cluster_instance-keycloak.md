# Task 004: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 76
- **Address**: `aws_rds_cluster_instance.keycloak`
- **Type**: `aws_rds_cluster_instance` → `AWS::RDS::DBInstance`

### TF Resource Block
```hcl
resource "aws_rds_cluster_instance" "keycloak" {
  cluster_identifier = aws_rds_cluster.keycloak.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.keycloak.engine
  engine_version     = aws_rds_cluster.keycloak.engine_version

  performance_insights_enabled = false

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::RDS::DBInstance
    Properties:
      DBClusterIdentifier: !Sub ${EnvironmentName}-keycloak
      Engine: ${aws_rds_cluster.keycloak.engine}
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