# Task 049: ADD Resource

**Action**: ADD
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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  KeycloakHttps:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakHttps` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks