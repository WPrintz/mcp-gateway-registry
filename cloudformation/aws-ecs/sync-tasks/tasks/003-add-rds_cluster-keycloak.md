# Task 003: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 40
- **Address**: `aws_rds_cluster.keycloak`
- **Type**: `aws_rds_cluster` → `AWS::RDS::DBCluster`

### TF Resource Block
```hcl
resource "aws_rds_cluster" "keycloak" {
  cluster_identifier = "keycloak"
  engine             = "aurora-mysql"
  engine_version     = "8.0.mysql_aurora.3.08.2"
  database_name      = "keycloak"
  master_username    = var.keycloak_database_username
  master_password    = var.keycloak_database_password

  db_subnet_group_name            = aws_db_subnet_group.keycloak.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.keycloak.name
  vpc_security_group_ids          = [aws_security_group.keycloak_db.id]

  # Backup and maintenance
  backup_retention_period      = 7
  preferred_backup_window      = "02:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true

  # Encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # Deletion protection
  deletion_protection = false
  skip_final_snapshot = true

  # Serverless v2 scaling
  serverlessv2_scaling_configuration {
    max_capacity = var.keycloak_database_max_acu
    min_capacity = var.keycloak_database_min_acu
  }

  tags = local.common_tags
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::RDS::DBCluster
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