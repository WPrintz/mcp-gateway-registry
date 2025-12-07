# Task 076: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/monitoring.tf`
- **Line**: 102
- **Address**: `module.mcp-gateway.aws_cloudwatch_metric_alarm.alb_unhealthy_targets`
- **Type**: `aws_cloudwatch_metric_alarm` → `UNKNOWN:aws_cloudwatch_metric_alarm`

### TF Resource Block
```hcl
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${local.name_prefix}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "ALB has unhealthy targets"
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

1. Add the resource `AlbUnhealthyTargets` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks