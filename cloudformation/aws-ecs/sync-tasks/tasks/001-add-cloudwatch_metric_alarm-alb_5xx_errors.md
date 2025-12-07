# Task 001: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/plan:module.mcp_gateway.aws_cloudwatch_metric_alarm.alb_5xx_errors[0]`
- **Line**: 0
- **Address**: `module.mcp_gateway.aws_cloudwatch_metric_alarm.alb_5xx_errors`
- **Type**: `aws_cloudwatch_metric_alarm` → `AWS::CloudWatch::Alarm`

### TF Resource Block
```hcl
{
  "actions_enabled": true,
  "alarm_actions": null,
  "alarm_description": "ALB is receiving too many 5XX errors",
  "alarm_name": "mcp-gateway-v2-alb-5xx-errors",
  "comparison_operator": "GreaterThanThreshold",
  "datapoints_to_alarm": null,
  "evaluation_periods": 2,
  "extended_statistic": null,
  "insufficient_data_actions": null,
  "metric_name": "HTTPCode_Target_5XX_Count",
  "metric_query": [],
  "namespace": "AWS/ApplicationELB",
  "ok_actions": null,
  "period": 300,
  "region": "us-east-1",
  "statistic": "Sum",
  "tags": null,
  "threshold": 10,
  "threshold_metric_id": null,
  "treat_missing_data": "missing",
  "unit": null
}
```

## Suggested CFN Template

Add to: `cloudformation/aws-ecs/templates/compute-stack.yaml`

```yaml
  Alb5xxErrors:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub ${EnvironmentName}-alb_5xx_errors
      AlarmDescription: ALB is receiving too many 5XX errors
      MetricName: HTTPCode_Target_5XX_Count
      Namespace: AWS/ApplicationELB
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 2
      Threshold: 10
      ComparisonOperator: GreaterThanThreshold
```

## Instructions

1. Add the resource `Alb5xxErrors` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks