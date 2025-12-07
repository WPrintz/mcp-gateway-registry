# Task 014: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:aws_security_group.vpc_endpoints`
- **Line**: 0
- **Address**: `aws_security_group.vpc_endpoints`
- **Type**: `aws_security_group` → `AWS::EC2::SecurityGroup`

### TF Resource Block
```hcl
{
  "description": "Security group for VPC endpoints",
  "ingress": [
    {
      "cidr_blocks": [
        "10.0.0.0/16"
      ],
      "description": "",
      "from_port": 443,
      "ipv6_cidr_blocks": [],
      "prefix_list_ids": [],
      "protocol": "tcp",
      "security_groups": [],
      "self": false,
      "to_port": 443
    }
  ],
  "name": "mcp-gateway-vpc-endpoints",
  "region": "us-east-1",
  "revoke_rules_on_delete": false,
  "tags": null,
  "timeouts": null
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/network-stack.yaml`
- **Logical ID**: `VpcEndpointsSG`
- **Type**: `AWS::EC2::SecurityGroup`

### CFN Resource Block
```yaml
  VpcEndpointsSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub ${EnvironmentName}-vpc-endpoints
      GroupDescription: Security group for VPC endpoints
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: !Ref VpcCidr
          Description: HTTPS from VPC
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-vpc-endpoints

  # Main ALB Security Group
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment