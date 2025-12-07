# TF-CFN Sync Summary

Generated: 2025-12-06T23:36:31.678208

## AI Assistant Instructions

When reviewing this summary:
1. **TF Only resources**: Check if they exist in CFN with different names
   - If yes: Add mapping to `tf-cfn-mappings.yaml`
   - If intentionally TF-only: Add to `skip_tf_patterns` in mappings file
   - If real gap: Add to CFN templates
2. **Low-confidence matches**: Verify the TF↔CFN pairing is correct
3. **After changes**: Re-run sync tool to verify improvements

## Overview

| Category | Count | Action |
|----------|-------|--------|
| Matched | 91 | Review low-confidence matches |
| TF Only | 7 | Add to CFN or mappings file |
| CFN Only | 72 | May be CFN-specific |
| Skipped | 165 | Intentionally different |

## Known Gaps (from mappings file)

- **module.mcp_gateway.aws_cloudwatch_metric_alarm.***: Monitoring alarms for ALB errors, response time, CPU/memory
  - Recommendation: Add AWS::CloudWatch::Alarm resources to services-stack.yaml
  - Priority: medium

## Tasks Generated

### Resources to Add

These TF resources have no matching CFN resource. Either:
- Add them to CFN templates
- Add a mapping to `tf-cfn-mappings.yaml` if they exist with different names
- Add to `skip_tf_patterns` if intentionally TF-only

- [ ] Task 001: ADD `module.mcp_gateway.aws_cloudwatch_metric_alarm.alb_5xx_errors[0]` → `Alb5xxErrors`
- [ ] Task 002: ADD `module.mcp_gateway.aws_cloudwatch_metric_alarm.alb_response_time[0]` → `AlbResponseTime`
- [ ] Task 003: ADD `module.mcp_gateway.aws_cloudwatch_metric_alarm.alb_unhealthy_targets[0]` → `AlbUnhealthyTargets`
- [ ] Task 004: ADD `module.mcp_gateway.aws_cloudwatch_metric_alarm.auth_cpu_high[0]` → `AuthCpuHigh`
- [ ] Task 005: ADD `module.mcp_gateway.aws_cloudwatch_metric_alarm.auth_memory_high[0]` → `AuthMemoryHigh`
- [ ] Task 006: ADD `module.mcp_gateway.aws_cloudwatch_metric_alarm.registry_cpu_high[0]` → `RegistryCpuHigh`
- [ ] Task 007: ADD `module.mcp_gateway.aws_cloudwatch_metric_alarm.registry_memory_high[0]` → `RegistryMemoryHigh`

### Resources to Review for Drift

These matches have low confidence scores. Verify they're correct:

- [ ] Task 008: REVIEW `module.vpc.aws_route.private_nat_gateway` ↔ `DefaultPrivateRoute1` (score: 0.33)
- [ ] Task 009: REVIEW `module.vpc.aws_route.private_nat_gateway` ↔ `DefaultPrivateRoute2` (score: 0.33)
- [ ] Task 010: REVIEW `module.vpc.aws_route.private_nat_gateway` ↔ `DefaultPrivateRoute3` (score: 0.33)
- [ ] Task 011: REVIEW `module.vpc.aws_route.public_internet_gateway` ↔ `DefaultPublicRoute` (score: 0.33)
- [ ] Task 012: REVIEW `aws_appautoscaling_policy.keycloak_cpu` ↔ `KeycloakCpuScalingPolicy` (score: 0.80)
- [ ] Task 013: REVIEW `aws_appautoscaling_policy.keycloak_memory` ↔ `KeycloakMemoryScalingPolicy` (score: 0.80)
- [ ] Task 014: REVIEW `aws_appautoscaling_target.keycloak` ↔ `KeycloakScalableTarget` (score: 0.80)
- [ ] Task 015: REVIEW `aws_ecr_repository.keycloak` ↔ `KeycloakEcrRepository` (score: 0.80)
- [ ] Task 016: REVIEW `aws_lb_listener.keycloak_http` ↔ `KeycloakHttpListener` (score: 0.80)
- [ ] Task 017: REVIEW `aws_security_group.keycloak_ecs` ↔ `KeycloakEcsSG` (score: 0.80)
- [ ] Task 018: REVIEW `aws_security_group.vpc_endpoints` ↔ `VpcEndpointsSG` (score: 0.80)
- [ ] Task 019: REVIEW `aws_vpc_endpoint.s3` ↔ `S3Endpoint` (score: 0.80)
- [ ] Task 020: REVIEW `aws_vpc_endpoint.sts` ↔ `STSEndpoint` (score: 0.80)
- [ ] Task 021: REVIEW `module.ecs_cluster.aws_iam_role.task_exec` ↔ `EcsTaskExecutionRole` (score: 0.80)

## Statistics

- High-confidence matches (score >= 0.9): 77
- Low-confidence matches (score < 0.9): 14
- Skipped via patterns: 165
