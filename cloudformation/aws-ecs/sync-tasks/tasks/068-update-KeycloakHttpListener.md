# Task 068: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-alb.tf`
- **Line**: 89
- **Address**: `aws_lb_listener.keycloak_http_redirect`
- **Type**: `aws_lb_listener` → `AWS::ElasticLoadBalancingV2::Listener`

### TF Resource Block
```hcl
resource "aws_lb_listener" "keycloak_http_redirect" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.common_tags
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `KeycloakHttpListener`
- **Type**: `AWS::ElasticLoadBalancingV2::Listener`

### CFN Resource Block
```yaml
  KeycloakHttpListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      LoadBalancerArn: !Ref KeycloakAlb
      Port: 80
      Protocol: HTTP
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref KeycloakTargetGroup

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment