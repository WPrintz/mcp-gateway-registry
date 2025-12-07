# Task 019: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:module.vpc.aws_route.private_nat_gateway[1]`
- **Line**: 0
- **Address**: `module.vpc.aws_route.private_nat_gateway`
- **Type**: `aws_route` → `AWS::EC2::Route`

### TF Resource Block
```hcl
{
  "carrier_gateway_id": null,
  "core_network_arn": null,
  "destination_cidr_block": "0.0.0.0/0",
  "destination_ipv6_cidr_block": null,
  "destination_prefix_list_id": null,
  "egress_only_gateway_id": null,
  "gateway_id": null,
  "local_gateway_id": null,
  "region": "us-east-1",
  "timeouts": {
    "create": "5m",
    "delete": null,
    "update": null
  },
  "transit_gateway_id": null,
  "vpc_endpoint_id": null,
  "vpc_peering_connection_id": null
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/network-stack.yaml`
- **Logical ID**: `DefaultPrivateRoute2`
- **Type**: `AWS::EC2::Route`

### CFN Resource Block
```yaml
  DefaultPrivateRoute2:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable2
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway2

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment