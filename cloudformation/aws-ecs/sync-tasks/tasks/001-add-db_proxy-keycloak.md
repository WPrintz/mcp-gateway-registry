# Task 001: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 6
- **Address**: `aws_db_proxy.keycloak`
- **Type**: `aws_db_proxy` → `AWS::RDS::DBProxy`

### TF Resource Block
```hcl
resource "aws_db_proxy" "keycloak" {
  name          = "keycloak-proxy"
  engine_family = "MYSQL"

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.keycloak_db_secret.arn
  }

  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_subnet_ids         = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.keycloak_db.id]

  require_tls = false

  tags = local.common_tags

  depends_on = [
    aws_secretsmanager_secret_version.keycloak_db_secret
  ]
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/data-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::RDS::DBProxy
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