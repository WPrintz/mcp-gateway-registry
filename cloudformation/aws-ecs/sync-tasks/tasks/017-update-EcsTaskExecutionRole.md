# Task 017: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:module.ecs_cluster.aws_iam_role.task_exec[0]`
- **Line**: 0
- **Address**: `module.ecs_cluster.aws_iam_role.task_exec`
- **Type**: `aws_iam_role` → `AWS::IAM::Role`

### TF Resource Block
```hcl
{
  "assume_role_policy": "{\"Statement\":[{\"Action\":\"sts:AssumeRole\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ecs-tasks.amazonaws.com\"},\"Sid\":\"ECSTaskExecutionAssumeRole\"}],\"Version\":\"2012-10-17\"}",
  "description": "Task execution role for mcp-gateway-ecs-cluster",
  "force_detach_policies": true,
  "max_session_duration": 3600,
  "name_prefix": "mcp-gateway-task-execution-",
  "path": "/",
  "permissions_boundary": null,
  "tags": {
    "Name": "mcp-gateway ECS Cluster"
  },
  "tags_all": {
    "Name": "mcp-gateway ECS Cluster"
  }
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `EcsTaskExecutionRole`
- **Type**: `AWS::IAM::Role`

### CFN Resource Block
```yaml
  EcsTaskExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub ${EnvironmentName}-task-execution
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
        - PolicyName: SecretsAccess
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - secretsmanager:GetSecretValue
                Resource:
                  - !ImportValue
                    Fn::Sub: ${EnvironmentName}-SecretKeySecretArn
                  - !ImportValue
                    Fn::Sub: ${EnvironmentName}-AdminPasswordSecretArn
                  - !ImportValue
                    Fn::Sub: ${EnvironmentName}-KeycloakClientSecretArn
                  - !ImportValue
                    Fn::Sub: ${EnvironmentName}-KeycloakM2MClientSecretArn
              - Effect: Allow
                Action:
                  - ssm:GetParameters
                  - ssm:GetParameter
                Resource:
                  - !Sub arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/keycloak/*
        - PolicyName: EcsExecLogging
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogStream
                  - logs:DescribeLogGroups
                  - logs:DescribeLogStreams
                  - logs:PutLogEvents
                Resource: arn:aws:logs:*:*:*
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-task-execution

```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment