# Task 002: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:module.mcp_gateway.aws_cloudwatch_metric_alarm.alb_response_time[0]`
- **Line**: 0
- **Address**: `module.mcp_gateway.aws_cloudwatch_metric_alarm.alb_response_time`
- **Type**: `aws_cloudwatch_metric_alarm` → `AWS::CloudWatch::Alarm`

### TF Resource Block
```hcl
{
  "actions_enabled": true,
  "alarm_actions": null,
  "alarm_description": "ALB response time is too high",
  "alarm_name": "mcp-gateway-v2-alb-response-time",
  "comparison_operator": "GreaterThanThreshold",
  "datapoints_to_alarm": null,
  "evaluation_periods": 2,
  "extended_statistic": null,
  "insufficient_data_actions": null,
  "metric_name": "TargetResponseTime",
  "metric_query": [],
  "namespace": "AWS/ApplicationELB",
  "ok_actions": null,
  "period": 300,
  "region": "us-east-1",
  "statistic": "Average",
  "tags": null,
  "threshold": 1,
  "threshold_metric_id": null,
  "treat_missing_data": "missing",
  "unit": null
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  AlbResponseTime:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub ${EnvironmentName}-alb_response_time
      AlarmDescription: ALB response time is too high
      MetricName: TargetResponseTime
      Namespace: AWS/ApplicationELB
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 1
      ComparisonOperator: GreaterThanThreshold
```

## Instructions

1. Add the resource `AlbResponseTime` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks