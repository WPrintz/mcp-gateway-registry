# Task 002: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 29
- **Address**: `aws_db_proxy_target.keycloak`
- **Type**: `aws_db_proxy_target` → `AWS::RDS::DBProxyTargetGroup`

### TF Resource Block
```hcl
resource "aws_db_proxy_target" "keycloak" {
  db_proxy_name         = aws_db_proxy.keycloak.name
  target_group_name     = "default"
  db_cluster_identifier = aws_rds_cluster.keycloak.cluster_identifier

  depends_on = [
    aws_rds_cluster_instance.keycloak
  ]
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::RDS::DBProxyTargetGroup
    Properties:
      DBProxyName: !Sub ${EnvironmentName}-keycloak-proxy
      EngineFamily: MYSQL
      Auth:
        - AuthScheme: SECRETS
          SecretArn: !Ref KeycloakDbSecret  # TODO: verify reference
          IAMAuth: DISABLED
      RoleArn: !GetAtt RdsProxyRole.Arn
      VpcSubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
        - !Ref PrivateSubnet3
      VpcSecurityGroupIds:
        - !Ref DatabaseSG
      RequireTLS: false
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks