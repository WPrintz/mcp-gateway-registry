# Task 049: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 120
- **Address**: `aws_kms_key.rds`
- **Type**: `aws_kms_key` → `AWS::KMS::Key`

### TF Resource Block
```hcl
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/data-stack.yaml`
- **Logical ID**: `RdsKmsKey`
- **Type**: `AWS::KMS::Key`

### CFN Resource Block
```yaml
  RdsKmsKey:
    Type: AWS::KMS::Key
    Properties:
      Description: KMS key for RDS encryption
      EnableKeyRotation: true
      KeyPolicy:
        Version: '2012-10-17'
        Statement:
          - Sid: Enable IAM User Permissions
            Effect: Allow
            Principal:
              AWS: !Sub arn:aws:iam::${AWS::AccountId}:root
            Action: kms:*
            Resource: '*'
          - Sid: Allow RDS to use the key
            Effect: Allow
            Principal:
              Service: rds.amazonaws.com
            Action:
              - kms:Encrypt
              - kms:Decrypt
              - kms:ReEncrypt*
              - kms:GenerateDataKey*
              - kms:DescribeKey
            Resource: '*'
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-rds-kms

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment