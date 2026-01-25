# MCP Gateway Registry - Observability Setup

This guide explains how to enable observability features for the MCP Gateway Registry workshop deployment using Amazon Managed Prometheus (AMP) and Amazon Managed Grafana (AMG).

## Overview

The observability stack provides:
- **Amazon Managed Prometheus (AMP)**: Metrics collection and storage
- **Amazon Managed Grafana (AMG)**: Dashboard visualization
- **ADOT Collector**: AWS Distro for OpenTelemetry for metrics export
- **CloudWatch Dashboard**: Quick overview dashboard

## Prerequisites

1. IAM Identity Center (AWS SSO) configured for Grafana authentication
2. MCP Gateway Registry base deployment completed
3. AWS CLI configured with appropriate permissions

## Deployment Steps

### Step 1: Deploy the Observability Stack

Deploy the observability stack first to create the AMP and AMG workspaces:

```bash
aws cloudformation deploy \
  --template-file templates/observability-stack.yaml \
  --stack-name mcp-gateway-observability \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EnvironmentName=mcp-gateway \
    EnableAlerts=true
```

### Step 2: Get the AMP Remote Write Endpoint

After deployment, retrieve the AMP remote write endpoint:

```bash
aws cloudformation describe-stacks \
  --stack-name mcp-gateway-observability \
  --query 'Stacks[0].Outputs[?OutputKey==`PrometheusEndpoint`].OutputValue' \
  --output text
```

### Step 3: Enable ADOT Collector in Services Stack

Update the services stack with the AMP endpoint to enable metrics collection:

```bash
aws cloudformation deploy \
  --template-file templates/services-stack.yaml \
  --stack-name mcp-gateway-services \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EnvironmentName=mcp-gateway \
    EnableADOTSidecar=true \
    AMPRemoteWriteEndpoint=<AMP_ENDPOINT_FROM_STEP_2>
```

### Step 4: Configure Grafana Data Source

1. Access the Grafana workspace URL from the stack outputs
2. Add Amazon Managed Prometheus as a data source
3. Use the Prometheus Query Endpoint from the observability stack outputs

## CloudWatch Dashboard

A CloudWatch dashboard is automatically created with:
- ECS Service CPU/Memory utilization
- ALB request counts and response times
- HTTP response code distribution
- DocumentDB connections
- EFS throughput
- Aurora Serverless ACU usage

Access it at: `CloudWatch > Dashboards > mcp-gateway-overview`

## Grafana Dashboards

Import pre-built dashboards for:
- MCP Gateway Overview
- Tool Invocation Metrics
- User Activity
- Security Scan Results

### Sample Grafana Dashboard JSON

```json
{
  "title": "MCP Gateway Overview",
  "panels": [
    {
      "title": "Request Rate",
      "type": "graph",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total[5m]))",
          "legendFormat": "Requests/sec"
        }
      ]
    },
    {
      "title": "Error Rate",
      "type": "stat",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100",
          "legendFormat": "Error %"
        }
      ]
    }
  ]
}
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
   aws logs tail /ecs/mcp-gateway/adot-collector --follow
   ```

2. Verify IAM permissions for `aps:RemoteWrite`

3. Confirm the AMP endpoint is correct

### Grafana Cannot Query Prometheus

1. Verify the Grafana workspace role has `AmazonPrometheusQueryAccess`
2. Check the data source configuration uses SigV4 authentication
3. Ensure the correct region is specified

### No Metrics Appearing

1. Verify ECS services are running
2. Check service discovery configuration
3. Confirm metrics endpoints are accessible within the VPC

## Architecture

```
ECS Services ─────> ADOT Collector ─────> Amazon Managed Prometheus
                                                      │
                                                      ▼
CloudWatch ◄──────────────────────────────── Amazon Managed Grafana
```

## Cost Considerations

- **AMP**: Pay for metrics ingested and stored (~$0.03/million samples)
- **AMG**: Pay per active user per hour (~$9/user/month)
- **ADOT Collector**: Minimal Fargate cost (256 CPU, 512 MB memory)

## Lab 7 Walkthrough

For the workshop Lab 7 (Observability), participants will:

1. Navigate to the CloudWatch dashboard to view service metrics
2. Access the Grafana workspace to explore custom dashboards
3. Create a simple query to view tool invocation rates
4. Set up a custom alert for high latency

See the workshop content for detailed step-by-step instructions.
