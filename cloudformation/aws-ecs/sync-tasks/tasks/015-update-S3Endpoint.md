# Task 015: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:aws_vpc_endpoint.s3`
- **Line**: 0
- **Address**: `aws_vpc_endpoint.s3`
- **Type**: `aws_vpc_endpoint` → `AWS::EC2::VPCEndpoint`

### TF Resource Block
```hcl
{
  "auto_accept": null,
  "region": "us-east-1",
  "resource_configuration_arn": null,
  "service_name": "com.amazonaws.us-east-1.s3",
  "service_network_arn": null,
  "tags": null,
  "timeouts": null,
  "vpc_endpoint_type": "Gateway"
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