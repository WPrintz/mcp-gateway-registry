# Task 016: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:aws_vpc_endpoint.sts`
- **Line**: 0
- **Address**: `aws_vpc_endpoint.sts`
- **Type**: `aws_vpc_endpoint` → `AWS::EC2::VPCEndpoint`

### TF Resource Block
```hcl
{
  "auto_accept": null,
  "private_dns_enabled": true,
  "region": "us-east-1",
  "resource_configuration_arn": null,
  "service_name": "com.amazonaws.us-east-1.sts",
  "service_network_arn": null,
  "tags": null,
  "timeouts": null,
  "vpc_endpoint_type": "Interface"
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/network-stack.yaml`
- **Logical ID**: `STSEndpoint`
- **Type**: `AWS::EC2::VPCEndpoint`

### CFN Resource Block
```yaml
  STSEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      VpcId: !Ref VPC
      ServiceName: !Sub com.amazonaws.${AWS::Region}.sts
      VpcEndpointType: Interface
      SubnetIds:
        - !Ref PrivateSubnet1
        - !Ref PrivateSubnet2
        - !Ref PrivateSubnet3
      SecurityGroupIds:
        - !Ref VpcEndpointsSG
      PrivateDnsEnabled: true

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment