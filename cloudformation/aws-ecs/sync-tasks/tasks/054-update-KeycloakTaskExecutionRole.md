# Task 054: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/keycloak-ecs.tf`
- **Line**: 101
- **Address**: `aws_iam_role.keycloak_task_exec_role`
- **Type**: `aws_iam_role` → `AWS::IAM::Role`

### TF Resource Block
```hcl
resource "aws_iam_role" "keycloak_task_exec_role" {
  name = "keycloak-task-exec-role-${var.aws_region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `KeycloakTaskExecutionRole`
- **Type**: `AWS::IAM::Role`

### CFN Resource Block
```yaml
  KeycloakTaskExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${EnvironmentName}-keycloak-task-execution
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ecs-tasks.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
      Policies:
        - PolicyName: KeycloakSecretsAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - secretsmanager:GetSecretValue
                Resource:
                  - !ImportValue
                    Fn::Sub: ${EnvironmentName}-KeycloakDbSecretArn
              - Effect: Allow
                Action:
                  - ssm:GetParameters
                  - ssm:GetParameter
                Resource:
                  - !Sub arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/keycloak/*
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-keycloak-task-execution

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment