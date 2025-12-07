# Task 065: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-alb.tf`
- **Line**: 5
- **Address**: `aws_lb.keycloak`
- **Type**: `aws_lb` → `AWS::ElasticLoadBalancingV2::LoadBalancer`

### TF Resource Block
```hcl
resource "aws_lb" "keycloak" {
  name               = "keycloak-alb"
  internal           = false
  load_balancer_type = "application"

  drop_invalid_header_fields = true
  enable_deletion_protection = false

  security_groups = [aws_security_group.keycloak_lb.id]
  subnets         = module.vpc.public_subnets

  tags = merge(
    local.common_tags,
    {
      Name = "keycloak-alb"
    }
  )
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `KeycloakAlb`
- **Type**: `AWS::ElasticLoadBalancingV2::LoadBalancer`

### CFN Resource Block
```yaml
  KeycloakAlb:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Name: !Sub ${EnvironmentName}-keycloak-alb
      Type: application
      Scheme: internet-facing
      SecurityGroups:
        - !ImportValue
          Fn::Sub: ${EnvironmentName}-KeycloakAlbSG
      Subnets: !Split
        - ','
        - !ImportValue
          Fn::Sub: ${EnvironmentName}-PublicSubnets
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-keycloak-alb

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment