# Task 072: ADD Resource

**Action**: ADD
**Priority**: MEDIUM

## Terraform Source

- **File**: `terraform/aws-ecs/modules/mcp-gateway/monitoring.tf`
- **Line**: 24
- **Address**: `module.mcp-gateway.aws_cloudwatch_metric_alarm.auth_cpu_high`
- **Type**: `aws_cloudwatch_metric_alarm` → `UNKNOWN:aws_cloudwatch_metric_alarm`

### TF Resource Block
```hcl
resource "aws_cloudwatch_metric_alarm" "auth_cpu_high" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${local.name_prefix}-auth-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Auth service CPU utilization is too high"
  alarm_actions       = var.alarm_email != "" ? [module.sns_alarms.topic_arn] : []

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = module.ecs_service_auth.name
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

1. Add the resource `AuthCpuHigh` to the appropriate CFN template
2. Update any !Ref placeholders with actual resource references
3. Add to Outputs if needed by other stacks