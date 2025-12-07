# Task 046: ADD Resource

**Action**: ADD
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

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Keycloak:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      # TODO: Add properties from TF resource
```

## Instructions

1. Add the resource `Keycloak` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks