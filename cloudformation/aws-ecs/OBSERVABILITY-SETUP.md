# MCP Gateway Registry - Observability Setup

This guide explains how to enable observability features for the MCP Gateway Registry workshop deployment using Amazon Managed Prometheus (AMP), Grafana OSS on ECS, and the ADOT Collector.

## Overview

The observability stack provides:
- **Amazon Managed Prometheus (AMP)**: Metrics collection and storage
- **Grafana OSS (on ECS)**: Dashboard visualization (pre-configured with dashboards and datasources)
- **ADOT Collector**: AWS Distro for OpenTelemetry for metrics scraping and export
- **Metrics Service**: Custom Prometheus exporter for MCP Gateway Registry metrics
- **CloudWatch Dashboard**: Quick overview dashboard

## Prerequisites

1. MCP Gateway Registry base deployment completed (network, data, compute, services stacks)
2. AWS CLI configured with appropriate permissions

## Deployment

The observability stack is deployed automatically as part of the nested stack deployment via `main-stack.yaml`. It depends on the services stack and is created after all ECS services are running.

### Manual Deployment (if deploying stacks individually)

```bash
aws cloudformation deploy \
  --template-file templates/observability-stack.yaml \
  --stack-name mcp-gateway-observability \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EnvironmentName=mcp-gateway \
    EnableAlerts=true
```

### Grafana Access

Grafana runs as an ECS service with anonymous access enabled (Admin role) for workshop convenience. Access it via the ALB endpoint from the stack outputs.

Pre-configured dashboards are baked into the Grafana container image (see `grafana/` directory):
- MCP Analytics Comprehensive dashboard
- AMP datasource pre-configured via provisioning

## CloudWatch Dashboard

A CloudWatch dashboard is automatically created with:
- ECS Service CPU/Memory utilization
- ALB request counts and response times
- HTTP response code distribution
- DocumentDB connections

Access it at: `CloudWatch > Dashboards > mcp-gateway-overview`

## Grafana Dashboards

Pre-built dashboards are automatically provisioned:
- MCP Gateway Overview
- Tool Invocation Metrics
- User Activity
- Security Scan Results

### Sample PromQL Queries

```promql
# Request rate
sum(rate(http_requests_total[5m]))

# Error rate percentage
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
```

## Alerting

Default alerts are configured when `EnableAlerts=true`:

| Alert | Condition | Severity |
|-------|-----------|----------|
| MCPGatewayHighErrorRate | Error rate > 5% for 5 min | Warning |
| MCPRegistryDown | Service unavailable for 2 min | Critical |
| MCPGatewayHighLatency | p95 latency > 2 sec for 5 min | Warning |

Configure SNS notifications by:
1. Creating an SNS topic subscription
2. Updating the AlertManager configuration in AMP

## Troubleshooting

### ADOT Collector Not Sending Metrics

1. Check ADOT collector logs:
   ```bash
   aws logs tail /ecs/mcp-gateway/adot-collector --follow --region us-east-2
   ```

2. Verify IAM permissions for `aps:RemoteWrite`

3. Confirm the AMP endpoint is correct

### Grafana Cannot Query Prometheus

1. Verify the Grafana task role has `AmazonPrometheusQueryAccess`
2. Check the datasource provisioning in `grafana/provisioning/datasources/`
3. Ensure the AMP endpoint env var is correctly passed to the Grafana container

### No Metrics Appearing

1. Verify ECS services are running and healthy
2. Check the metrics-service container logs
3. Confirm the ADOT collector can reach the metrics-service via Service Connect

## Architecture

```
ECS Services ──> Metrics Service (9465) ──> ADOT Collector ──> Amazon Managed Prometheus
                                                                        |
                                                                        v
                                                               Grafana OSS (ECS)
```

## Cost Considerations

- **AMP**: Pay for metrics ingested and stored (~$0.03/million samples)
- **Grafana OSS**: Fargate task cost only (no per-user licensing)
- **ADOT Collector**: Minimal Fargate cost (256 CPU, 512 MB memory)
- **Metrics Service**: Minimal Fargate cost

## Additional Documentation

See `docs/observability-architecture.md` for the detailed architecture design, including the metrics pipeline, ADOT scrape configuration, and implementation checklist.
