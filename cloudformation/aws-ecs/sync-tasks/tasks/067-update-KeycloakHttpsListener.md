# Task 067: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-alb.tf`
- **Line**: 73
- **Address**: `aws_lb_listener.keycloak_https`
- **Type**: `aws_lb_listener` → `AWS::ElasticLoadBalancingV2::Listener`

### TF Resource Block
```hcl
resource "aws_lb_listener" "keycloak_https" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.keycloak.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak.arn
  }

  tags = local.common_tags
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `KeycloakHttpsListener`
- **Type**: `AWS::ElasticLoadBalancingV2::Listener`

### CFN Resource Block
```yaml
  KeycloakHttpsListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Condition: HasDnsConfig
    Properties:
      LoadBalancerArn: !Ref KeycloakAlb
      Port: 443
      Protocol: HTTPS
      SslPolicy: ELBSecurityPolicy-TLS13-1-2-2021-06
      Certificates:
        - CertificateArn: !Ref KeycloakCertificate
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref KeycloakTargetGroup

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment