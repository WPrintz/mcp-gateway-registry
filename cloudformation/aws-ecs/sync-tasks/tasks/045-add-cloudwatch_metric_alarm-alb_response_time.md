# Task 045: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/monitoring.tf`
- **Line**: 140
- **Address**: `module.mcp-gateway.aws_cloudwatch_metric_alarm.alb_response_time`
- **Type**: `aws_cloudwatch_metric_alarm` → `AWS::CloudWatch::Alarm`

### TF Resource Block
```hcl
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${local.name_prefix}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ALB response time is too high"
  alarm_actions       = var.alarm_email != "" ? [module.sns_alarms.topic_arn] : []

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
  }
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