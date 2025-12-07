# Task 082: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-security-groups.tf`
- **Line**: 6
- **Address**: `aws_security_group.keycloak_ecs`
- **Type**: `aws_security_group` → `AWS::EC2::SecurityGroup`

### TF Resource Block
```hcl
resource "aws_security_group" "keycloak_ecs" {
  name        = "keycloak-ecs"
  description = "Security group for Keycloak ECS tasks"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "keycloak-ecs"
    }
  )
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/network-stack.yaml`
- **Logical ID**: `KeycloakEcsSG`
- **Type**: `AWS::EC2::SecurityGroup`

### CFN Resource Block
```yaml
  KeycloakEcsSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub ${EnvironmentName}-keycloak-ecs
      GroupDescription: Security group for Keycloak ECS tasks
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 8080
          ToPort: 8080
          SourceSecurityGroupId: !Ref KeycloakAlbSG
          Description: Keycloak from ALB
      SecurityGroupEgress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
          Description: HTTPS outbound
        - IpProtocol: udp
          FromPort: 53
          ToPort: 53
          CidrIp: 0.0.0.0/0
          Description: DNS outbound
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-keycloak-ecs

  # Database Security Group
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment