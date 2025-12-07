# Task 004: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:module.mcp_gateway.aws_cloudwatch_metric_alarm.auth_cpu_high[0]`
- **Line**: 0
- **Address**: `module.mcp_gateway.aws_cloudwatch_metric_alarm.auth_cpu_high`
- **Type**: `aws_cloudwatch_metric_alarm` → `AWS::CloudWatch::Alarm`

### TF Resource Block
```hcl
{
  "actions_enabled": true,
  "alarm_actions": null,
  "alarm_description": "Auth service CPU utilization is too high",
  "alarm_name": "mcp-gateway-v2-auth-cpu-high",
  "comparison_operator": "GreaterThanThreshold",
  "datapoints_to_alarm": null,
  "dimensions": {
    "ClusterName": "mcp-gateway-ecs-cluster",
    "ServiceName": "mcp-gateway-v2-auth"
  },
  "evaluation_periods": 2,
  "extended_statistic": null,
  "insufficient_data_actions": null,
  "metric_name": "CPUUtilization",
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
  AuthCpuHigh:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub ${EnvironmentName}-auth_cpu_high
      AlarmDescription: Auth service CPU utilization is too high
      MetricName: CPUUtilization
      Namespace: AWS/ECS
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 85
      ComparisonOperator: GreaterThanThreshold
```

## Instructions

1. Add the resource `AuthCpuHigh` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks