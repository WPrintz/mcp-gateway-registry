# Task 048: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-alb.tf`
- **Line**: 32
- **Address**: `aws_lb_target_group.keycloak`
- **Type**: `aws_lb_target_group` → `AWS::ElasticLoadBalancingV2::TargetGroup`

### TF Resource Block
```hcl
resource "aws_lb_target_group" "keycloak" {
  name                 = "keycloak-tg-${random_string.alb_tg_suffix.result}"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.vpc.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
    protocol            = "HTTP"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }

  tags = merge(
    local.common_tags,
    {
      Name = "keycloak-tg"
    }
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      stickiness[0].cookie_name
    ]
  }
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks