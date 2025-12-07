# Task 042: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/monitoring.tf`
- **Line**: 82
- **Address**: `module.mcp-gateway.aws_cloudwatch_metric_alarm.registry_memory_high`
- **Type**: `aws_cloudwatch_metric_alarm` → `AWS::CloudWatch::Alarm`

### TF Resource Block
```hcl
resource "aws_cloudwatch_metric_alarm" "registry_memory_high" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${local.name_prefix}-registry-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Registry service memory utilization is too high"
  alarm_actions       = var.alarm_email != "" ? [module.sns_alarms.topic_arn] : []

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = module.ecs_service_registry.name
  }
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  RegistryMemoryHigh:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub ${EnvironmentName}-registry_memory_high
      AlarmDescription: Registry service memory utilization is too high
      MetricName: MemoryUtilization
      Namespace: AWS/ECS
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 85
      ComparisonOperator: GreaterThanThreshold
```

## Instructions

1. Add the resource `RegistryMemoryHigh` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks