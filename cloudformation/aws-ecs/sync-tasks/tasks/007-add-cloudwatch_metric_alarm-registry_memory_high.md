# Task 007: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:module.mcp_gateway.aws_cloudwatch_metric_alarm.registry_memory_high[0]`
- **Line**: 0
- **Address**: `module.mcp_gateway.aws_cloudwatch_metric_alarm.registry_memory_high`
- **Type**: `aws_cloudwatch_metric_alarm` → `AWS::CloudWatch::Alarm`

### TF Resource Block
```hcl
{
  "actions_enabled": true,
  "alarm_actions": null,
  "alarm_description": "Registry service memory utilization is too high",
  "alarm_name": "mcp-gateway-v2-registry-memory-high",
  "comparison_operator": "GreaterThanThreshold",
  "datapoints_to_alarm": null,
  "dimensions": {
    "ClusterName": "mcp-gateway-ecs-cluster",
    "ServiceName": "mcp-gateway-v2-registry"
  },
  "evaluation_periods": 2,
  "extended_statistic": null,
  "insufficient_data_actions": null,
  "metric_name": "MemoryUtilization",
  "metric_query": [],
  "namespace": "AWS/ECS",
  "ok_actions": null,
  "period": 300,
  "region": "us-east-1",
  "statistic": "Average",
  "tags": null,
  "threshold": 85,
  "threshold_metric_id": null,
  "treat_missing_data": "missing",
  "unit": null
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