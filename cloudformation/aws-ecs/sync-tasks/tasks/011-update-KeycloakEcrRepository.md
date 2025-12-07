# Task 011: UPDATE Resource

**Action**: UPDATE
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:aws_ecr_repository.keycloak`
- **Line**: 0
- **Address**: `aws_ecr_repository.keycloak`
- **Type**: `aws_ecr_repository` → `AWS::ECR::Repository`

### TF Resource Block
```hcl
{
  "encryption_configuration": [],
  "force_delete": null,
  "image_scanning_configuration": [
    {
      "scan_on_push": true
    }
  ],
  "image_tag_mutability": "MUTABLE",
  "image_tag_mutability_exclusion_filter": [],
  "name": "keycloak",
  "region": "us-east-1",
  "timeouts": null
}
```

## CloudFormation Target

- **File**: `cloudformation/aws-ecs/templates/compute-stack.yaml`
- **Logical ID**: `KeycloakEcrRepository`
- **Type**: `AWS::ECR::Repository`

### CFN Resource Block
```yaml
  KeycloakEcrRepository:
    Type: AWS::ECR::Repository
    Properties:
      RepositoryName: !Sub ${EnvironmentName}-keycloak
      ImageScanningConfiguration:
        ScanOnPush: true
      ImageTagMutability: MUTABLE
      LifecyclePolicy:
        LifecyclePolicyText: |
          {
            "rules": [
              {
                "rulePriority": 10,
                "description": "Keep last 10 git SHA tagged images",
                "selection": {
                  "tagStatus": "tagged",
                  "tagPrefixList": ["sha-"],
                  "countType": "imageCountMoreThan",
                  "countNumber": 10
                },
                "action": { "type": "expire" }
              },
              {
                "rulePriority": 20,
                "description": "Expire untagged images older than 7 days",
                "selection": {
                  "tagStatus": "untagged",
                  "countType": "sinceImagePushed",
                  "countUnit": "days",
                  "countNumber": 7
                },
                "action": { "type": "expire" }
              }
            ]
          }
      RepositoryPolicyText:
        Version: '2012-10-17'
        Statement:
          - Sid: AllowECSPull
            Effect: Allow
            Principal:
              Service: ecs-tasks.amazonaws.com
            Action:
              - ecr:GetDownloadUrlForLayer
              - ecr:BatchGetImage
              - ecr:BatchCheckLayerAvailability
          - Sid: AllowPush
            Effect: Allow
            Principal:
              AWS: !Sub arn:aws:iam::${AWS::AccountId}:root
            Action:
              - ecr:GetDownloadUrlForLayer
              - ecr:BatchGetImage
              - ecr:BatchCheckLayerAvailability
              - ecr:PutImage
              - ecr:InitiateLayerUpload
              - ecr:UploadLayerPart
              - ecr:CompleteLayerUpload
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-
```

## Instructions

1. Compare TF and CFN properties for drift
2. Update CFN to match TF configuration
3. Test deployment in dev environment