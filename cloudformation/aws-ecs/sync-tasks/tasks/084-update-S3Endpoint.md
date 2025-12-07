# Task 084: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/vpc.tf`
- **Line**: 59
- **Address**: `aws_vpc_endpoint.s3`
- **Type**: `aws_vpc_endpoint` → `AWS::EC2::VPCEndpoint`

### TF Resource Block
```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "${local.gateway_endpoint_prefix}.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/network-stack.yaml`
- **Logical ID**: `S3Endpoint`
- **Type**: `AWS::EC2::VPCEndpoint`

### CFN Resource Block
```yaml
  S3Endpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub com.amazonaws.${AWS::Region}.s3
      VpcEndpointType: Gateway
      RouteTableIds:
        - !Ref PrivateRouteTable1
        - !Ref PrivateRouteTable2
        - !Ref PrivateRouteTable3

#============================================================================
# Outputs
#============================================================================
Outputs:
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment