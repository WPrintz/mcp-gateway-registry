# Task 064: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 125
- **Address**: `aws_security_group_rule.keycloak_db_ingress_ecs`
- **Type**: `aws_security_group_rule` → `AWS::EC2::SecurityGroupIngress`

### TF Resource Block
```hcl
resource "aws_security_group_rule" "keycloak_db_ingress_ecs" {
  description              = "Ingress to database from Keycloak ECS task"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak_db.id
  source_security_group_id = aws_security_group.keycloak_ecs.id
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/network-stack.yaml`
- **Logical ID**: `EcsTasksIngressFromAlb443`
- **Type**: `AWS::EC2::SecurityGroupIngress`

### CFN Resource Block
```yaml
  EcsTasksIngressFromAlb443:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref EcsTasksSG
      IpProtocol: tcp
      FromPort: 443
      ToPort: 443
      SourceSecurityGroupId: !Ref MainAlbSG
      Description: HTTPS from ALB

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment