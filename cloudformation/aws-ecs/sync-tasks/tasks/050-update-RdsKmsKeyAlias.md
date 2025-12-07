# Task 050: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-database.tf`
- **Line**: 128
- **Address**: `aws_kms_alias.rds`
- **Type**: `aws_kms_alias` → `AWS::KMS::Alias`

### TF Resource Block
```hcl
resource "aws_kms_alias" "rds" {
  name          = "alias/keycloak-rds"
  target_key_id = aws_kms_key.rds.key_id
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/data-stack.yaml`
- **Logical ID**: `RdsKmsKeyAlias`
- **Type**: `AWS::KMS::Alias`

### CFN Resource Block
```yaml
  RdsKmsKeyAlias:
    Type: AWS::KMS::Alias
    Properties:
      AliasName: !Sub alias/${EnvironmentName}-rds
      TargetKeyId: !Ref RdsKmsKey

  #============================================================================
  # EFS File System
  #============================================================================
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment