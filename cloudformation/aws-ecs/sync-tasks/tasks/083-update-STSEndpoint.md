# Task 083: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/vpc.tf`
- **Line**: 49
- **Address**: `aws_vpc_endpoint.sts`
- **Type**: `aws_vpc_endpoint` → `AWS::EC2::VPCEndpoint`

### TF Resource Block
```hcl
resource "aws_vpc_endpoint" "sts" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "${local.interface_endpoint_prefix}.${data.aws_region.current.region}.sts"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true
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