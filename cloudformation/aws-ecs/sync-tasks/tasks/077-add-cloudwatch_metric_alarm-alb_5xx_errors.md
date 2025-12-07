# Task 077: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/monitoring.tf`
- **Line**: 121
- **Address**: `module.mcp-gateway.aws_cloudwatch_metric_alarm.alb_5xx_errors`
- **Type**: `aws_cloudwatch_metric_alarm` → `UNKNOWN:aws_cloudwatch_metric_alarm`

### TF Resource Block
```hcl
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${local.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is receiving too many 5XX errors"
  alarm_actions       = var.alarm_email != "" ? [module.sns_alarms.topic_arn] : []

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
  }
}
```

## ⚠️ Unknown CFN Type

The Terraform type `aws_cloudwatch_metric_alarm` is not in the type mapping.

**Action required**:
1. Find the equivalent AWS::* CloudFormation type for `aws_cloudwatch_metric_alarm`
2. Add it to `TF_TO_CFN` mapping in `scripts/tf-cfn-sync.py`
3. Re-run the sync tool

## Instructions

1. Add the resource `Alb5xxErrors` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks