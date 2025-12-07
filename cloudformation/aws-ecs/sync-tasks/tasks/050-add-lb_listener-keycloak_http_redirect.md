# Task 050: ADD Resource

**Action**: ADD
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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  KeycloakHttpRedirect:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `KeycloakHttpRedirect` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks