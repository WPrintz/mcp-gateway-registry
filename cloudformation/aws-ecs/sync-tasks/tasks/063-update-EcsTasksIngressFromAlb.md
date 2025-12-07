# Task 063: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 53
- **Address**: `aws_security_group_rule.keycloak_ecs_ingress_lb`
- **Type**: `aws_security_group_rule` → `AWS::EC2::SecurityGroupIngress`

### TF Resource Block
```hcl
resource "aws_security_group_rule" "keycloak_ecs_ingress_lb" {
  description              = "Ingress from load balancer to Keycloak ECS task"
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.keycloak_ecs.id
  source_security_group_id = aws_security_group.keycloak_lb.id
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/network-stack.yaml`
- **Logical ID**: `EcsTasksIngressFromAlb`
- **Type**: `AWS::EC2::SecurityGroupIngress`

### CFN Resource Block
```yaml
  EcsTasksIngressFromAlb:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: !Ref EcsTasksSG
      IpProtocol: tcp
      FromPort: 80
      ToPort: 80
      SourceSecurityGroupId: !Ref MainAlbSG
      Description: HTTP from ALB

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment