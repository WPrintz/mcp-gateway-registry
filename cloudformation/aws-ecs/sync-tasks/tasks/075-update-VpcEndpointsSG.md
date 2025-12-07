# Task 075: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/vpc.tf`
- **Line**: 67
- **Address**: `aws_security_group.vpc_endpoints`
- **Type**: `aws_security_group` → `AWS::EC2::SecurityGroup`

### TF Resource Block
```hcl
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
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