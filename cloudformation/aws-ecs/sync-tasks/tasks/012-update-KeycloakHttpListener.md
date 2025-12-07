# Task 012: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:aws_lb_listener.keycloak_http[0]`
- **Line**: 0
- **Address**: `aws_lb_listener.keycloak_http`
- **Type**: `aws_lb_listener` → `AWS::ElasticLoadBalancingV2::Listener`

### TF Resource Block
```hcl
{
  "alpn_policy": null,
  "certificate_arn": null,
  "default_action": [
    {
      "authenticate_cognito": [],
      "authenticate_oidc": [],
      "fixed_response": [],
      "forward": [],
      "jwt_validation": [],
      "redirect": [],
      "type": "forward"
    }
  ],
  "port": 80,
  "protocol": "HTTP",
  "region": "us-east-1",
  "timeouts": null
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