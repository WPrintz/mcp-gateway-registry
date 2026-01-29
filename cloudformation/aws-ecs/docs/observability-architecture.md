# MCP Gateway Observability Architecture for AWS ECS

This document describes the observability architecture for the MCP Gateway Registry when deployed on AWS ECS using CloudFormation. It explains the design decisions, trade-offs considered, and implementation approach.

## Executive Summary

The AWS ECS deployment uses a **metrics-service pattern** consistent with local development, but with AWS-native services (Amazon Managed Prometheus, Grafana OSS on ECS) replacing local components (Prometheus, Grafana containers). This provides operational consistency across environments while leveraging AWS managed services for durability and scalability.

## Background

### Local Development Architecture

The local docker-compose deployment includes a complete observability stack:

```
┌─────────────────────────────────────────────────────────┐
│                 Local Docker Services                    │
│  ┌───────────┐  ┌───────────┐  ┌───────────────────┐   │
│  │ Registry  │  │ Auth      │  │ MCP Servers       │   │
│  │           │  │ Server    │  │                   │   │
│  └─────┬─────┘  └─────┬─────┘  └─────────┬─────────┘   │
│        └──────────────┴──────────────────┘              │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP POST /metrics (port 8890)
                         ▼
         ┌───────────────────────────────────────────────┐
         │   metrics-service Container                    │
         │   - FastAPI application                       │
         │   - Receives metrics via HTTP API             │
         │   - Validates and buffers metrics             │
         │   - SQLite storage for historical analysis    │
         │   - OpenTelemetry instrumentation             │
         │   - Prometheus endpoint on port 9465          │
         └───────────────┬───────────────────────────────┘
                         │ Scrapes :9465/metrics
                         ▼
         ┌───────────────────────────────────────────────┐
         │   Prometheus Container                         │
         │   - Scrapes metrics-service every 15s         │
         │   - Local TSDB storage                        │
         │   - 200h retention                            │
         └───────────────┬───────────────────────────────┘
                         │ PromQL queries
                         ▼
         ┌───────────────────────────────────────────────┐
         │   Grafana Container                            │
         │   - Pre-built MCP Analytics dashboard         │
         │   - Real-time visualization                   │
         └───────────────────────────────────────────────┘
```

Key components:
- **metrics-service**: Custom FastAPI service that aggregates metrics from all MCP components
- **Prometheus**: Time-series database for metrics storage
- **Grafana**: Visualization and dashboards

### Terraform Deployment (Current State)

The existing Terraform deployment does **not** include observability infrastructure:
- No metrics-service deployment
- No Prometheus or AMP
- No Grafana or AMG
- Only CloudWatch Logs for basic logging

This means custom application metrics (tool execution times, auth success rates, discovery latency) are not collected in AWS deployments.

## Options Considered

We evaluated four approaches for AWS ECS observability:

### Option 1: Deploy metrics-service to ECS

Deploy the existing metrics-service container to ECS, with ADOT scraping its Prometheus endpoint and forwarding to AMP.

| Pros | Cons |
|------|------|
| Already built and tested locally | Adds another ECS service to maintain |
| No changes to registry/auth code | Extra network hop for metrics flow |
| Consistent with local dev environment | SQLite persistence requires EFS or accepts data loss |
| Supports all existing metric types | Additional container to build/deploy |
| Centralized metrics aggregation | |

### Option 2: Add OpenTelemetry SDK directly to registry

Instrument the registry and auth-server directly with the OpenTelemetry SDK, emitting metrics via OTLP to an ADOT sidecar.

| Pros | Cons |
|------|------|
| Cloud-native, industry standard | Requires code changes to registry |
| Direct integration, no middleman | Must update auth-server too |
| Lower latency | Refactor existing MetricsClient |
| Works with AWS X-Ray for tracing | Testing locally requires OTEL collector |
| No additional service to deploy | Different pattern than local dev |

### Option 3: Add Prometheus client to registry (expose /metrics)

Add prometheus-client library to expose a `/metrics` endpoint directly on the registry, with ADOT scraping each service instance.

| Pros | Cons |
|------|------|
| Simple, minimal code changes | Pull model requires service discovery |
| Industry standard format | ADOT must discover/reach each task |
| Easy to test locally | No aggregation across instances |
| Low overhead | Each service needs its own /metrics |
| | Different pattern than local dev |

### Option 4: CloudWatch-only (match Terraform)

Skip AMP/Grafana entirely. Use CloudWatch Metrics and Logs only, optionally with EMF (Embedded Metric Format).

| Pros | Cons |
|------|------|
| Simplest - no additional services | Less powerful than PromQL |
| Native AWS integration | CloudWatch dashboards less flexible |
| No code changes if using EMF | No pre-built MCP dashboards |
| Lower cost for low volume | Harder to correlate metrics |
| Already partially working | Inconsistent with local dev |

## Decision

**Selected: Option 1 (Deploy metrics-service) with modifications**

### Rationale

1. **Consistency with local development**: The metrics-service pattern is already documented, tested, and understood. Workshop participants who run locally will see the same architecture in AWS.

2. **No application code changes**: The registry and auth-server already emit metrics to `METRICS_SERVICE_URL`. We only need to deploy the service and configure the environment variable.

3. **Existing dashboards work**: The Grafana dashboards created for local development query the same Prometheus metrics. They work without modification.

4. **Centralized aggregation**: The metrics-service aggregates metrics from all services before exposing them. This simplifies ADOT configuration (single scrape target) and provides consistent metric naming.

5. **Documented and supported**: The metrics-service has comprehensive documentation including API reference, deployment guide, and troubleshooting.

### Modification for AWS

The local metrics-service uses SQLite for historical storage. In ECS Fargate:
- Task storage is ephemeral (lost on restart/scaling)
- EFS would add cost ($0.30/GB-month) and complexity
- SQLite doesn't support concurrent writes from multiple tasks

**Solution**: Configure metrics-service for **streaming-only mode**:
- SQLite storage is optional/ephemeral (accept data loss on task restart)
- Prometheus endpoint (`:9465`) serves real-time metrics
- ADOT scrapes and remote writes to AMP
- **AMP becomes the durable store** (replacing SQLite's role)

This preserves the metrics-service benefits while using AWS-native durability.

## Final Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ECS Services                                 │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ │
│  │    Registry     │  │   Auth Server   │  │   Other Services    │ │
│  │                 │  │                 │  │   (MCP Servers)     │ │
│  │ METRICS_SERVICE │  │ METRICS_SERVICE │  │  No custom metrics  │ │
│  │ _URL=http://    │  │ _URL=http://    │  │  (CloudWatch only)  │ │
│  │ metrics:8890    │  │ metrics:8890    │  │                     │ │
│  │ METRICS_API_KEY │  │ METRICS_API_KEY │  │                     │ │
│  └────────┬────────┘  └────────┬────────┘  └─────────────────────┘ │
│           │                    │                                     │
│           └────────────────────┘                                     │
│                                │                                     │
└────────────────────────────────┼─────────────────────────────────────┘
                                 │
                                 │ HTTP POST /metrics
                                 │ Header: X-API-Key: <METRICS_API_KEY>
                                 ▼
              ┌──────────────────────────────────────────┐
              │      metrics-service (ECS Task)          │
              │      METRICS_API_KEY_REGISTRY=<key>      │
              │                                          │
              │  ┌────────────────────────────────────┐ │
              │  │ FastAPI Application                 │ │
              │  │ - Receives metrics via HTTP API    │ │
              │  │ - API key auth (METRICS_API_KEY_*) │ │
              │  │ - Rate limiting (1000 req/min)     │ │
              │  │ - Request validation               │ │
              │  │ - In-memory buffering (5s flush)   │ │
              │  └────────────────────────────────────┘ │
              │                                          │
              │  ┌────────────────────────────────────┐ │
              │  │ OpenTelemetry Instrumentation      │ │
              │  │ - Counters: auth, tool, discovery  │ │
              │  │ - Histograms: latency, duration    │ │
              │  │ - Prometheus exporter :9465        │ │
              │  └────────────────────────────────────┘ │
              │                                          │
              │  ┌────────────────────────────────────┐ │
              │  │ SQLite (Optional/Ephemeral)        │ │
              │  │ - Local buffering only             │ │
              │  │ - Not relied upon for durability   │ │
              │  └────────────────────────────────────┘ │
              │                                          │
              │  Ports: 8890 (API), 9465 (Prometheus)   │
              └──────────────────┬───────────────────────┘
                                 │
                                 │ Scrapes :9465/metrics
                                 │ Every 15 seconds
                                 ▼
              ┌──────────────────────────────────────────┐
              │      ADOT Collector (ECS Task)           │
              │                                          │
              │  ┌────────────────────────────────────┐ │
              │  │ Prometheus Receiver                 │ │
              │  │ - Scrapes metrics-service:9465     │ │
              │  │ - 15s scrape interval              │ │
              │  └────────────────────────────────────┘ │
              │                                          │
              │  ┌────────────────────────────────────┐ │
              │  │ AWS Prometheus Remote Write        │ │
              │  │ - SigV4 authentication             │ │
              │  │ - Writes to AMP workspace          │ │
              │  └────────────────────────────────────┘ │
              │                                          │
              └──────────────────┬───────────────────────┘
                                 │
                                 │ Remote Write (SigV4)
                                 │ https://aps-workspaces.region.amazonaws.com
                                 ▼
              ┌──────────────────────────────────────────┐
              │   Amazon Managed Prometheus (AMP)        │
              │                                          │
              │  - Fully managed Prometheus-compatible  │
              │  - Automatic scaling                    │
              │  - 150-day default retention            │
              │  - PromQL query support                 │
              │  - SigV4 authentication                 │
              │  - No infrastructure to manage          │
              │                                          │
              │  Workspace: ${EnvironmentName}-prometheus│
              └──────────────────┬───────────────────────┘
                                 │
                                 │ PromQL Queries (SigV4)
                                 ▼
              ┌──────────────────────────────────────────┐
              │      Grafana OSS (ECS Task)              │
              │                                          │
              │  ┌────────────────────────────────────┐ │
              │  │ Pre-configured Datasources         │ │
              │  │ - Amazon Managed Prometheus (AMP)  │ │
              │  │   - SigV4 auth via IAM task role   │ │
              │  │ - CloudWatch                       │ │
              │  │   - ECS Container Insights         │ │
              │  └────────────────────────────────────┘ │
              │                                          │
              │  ┌────────────────────────────────────┐ │
              │  │ Pre-loaded Dashboards              │ │
              │  │ - MCP Analytics Comprehensive      │ │
              │  │   - Protocol activity              │ │
              │  │   - Auth flow analysis             │ │
              │  │   - Tool execution latency         │ │
              │  │   - Discovery metrics              │ │
              │  │ - AWS Infrastructure               │ │
              │  │   - ECS CPU/Memory                 │ │
              │  │   - ALB request counts             │ │
              │  │   - Task health                    │ │
              │  └────────────────────────────────────┘ │
              │                                          │
              │  Access: https://cloudfront/grafana/    │
              │  Auth: Anonymous (workshop simplicity)  │
              └──────────────────────────────────────────┘
```

## Component Details

### Services Emitting Metrics

The following services emit custom metrics to the metrics-service:

| Service | Metrics Emitted | Configuration |
|---------|-----------------|---------------|
| **Registry** | Tool discovery, tool execution, registry operations, health checks | Uses `METRICS_API_KEY` env var |
| **Auth-server** | Authentication requests, session operations | Uses `METRICS_API_KEY` env var |

**Note**: MCP servers (CurrentTime, MCPGW, RealServerFakeTools, etc.) do not emit custom metrics to metrics-service. They are monitored via ECS Container Insights and CloudWatch metrics only.

The metrics emission flow:
1. Registry/Auth-server instantiate `MetricsClient` from `registry/metrics/client.py`
2. The client reads `METRICS_SERVICE_URL` and `METRICS_API_KEY` from environment variables
3. Metrics are sent via HTTP POST to `{METRICS_SERVICE_URL}/metrics` with `X-API-Key` header

### API Key Authentication Configuration

The metrics-service uses a dual naming convention for API keys:

**Client Side** (registry, auth-server):
- Environment variable: `METRICS_API_KEY`
- Used to authenticate when sending metrics to metrics-service
- Set in task definitions from the `MetricsApiKey` CloudFormation parameter

**Server Side** (metrics-service):
- Environment variable pattern: `METRICS_API_KEY_<SERVICE>`
- The `setup_preshared_api_keys()` function in `metrics-service/app/main.py` discovers all environment variables matching `METRICS_API_KEY_*` on startup
- Each key is automatically registered with the service name derived from the suffix (e.g., `METRICS_API_KEY_REGISTRY` registers key for service `registry`)

Example auto-registration logic:
```python
# From metrics-service/app/main.py:129-159
for key, value in os.environ.items():
    if key.startswith('METRICS_API_KEY_') and value:
        # METRICS_API_KEY_REGISTRY -> service_name = "registry"
        service_suffix = key.replace('METRICS_API_KEY_', '')
        service_name = service_suffix.lower().replace('_', '-')
        # Register API key for this service...
```

**CloudFormation Parameter**:

The `MetricsApiKey` parameter centralizes API key configuration:

| Property | Value |
|----------|-------|
| Location | `services-stack.yaml` Parameters section (line ~294) |
| Type | String |
| NoEcho | `true` (masked in console) |
| Default | `workshop-metrics-key-2026` |

Used in 3 task definitions:
1. **Registry** (`RegistryTaskDefinition`) - as `METRICS_API_KEY`
2. **Auth-server** (`AuthServerTaskDefinition`) - as `METRICS_API_KEY`
3. **Metrics-service** (`MetricsServiceTaskDefinition`) - as `METRICS_API_KEY_REGISTRY`

To rotate the API key, update the `MetricsApiKey` parameter and redeploy the services stack.

### metrics-service

The metrics-service is deployed as an ECS Fargate task:

| Configuration | Value | Notes |
|--------------|-------|-------|
| Image | `${ECR}/mcp-gateway-metrics-service:latest` | Built via CodeBuild |
| CPU | 256 | 0.25 vCPU |
| Memory | 512 | 512 MB |
| Port 8890 | HTTP API | Receives metrics from services |
| Port 9465 | Prometheus | Scraped by ADOT |
| Health Check | `GET /health` | 30s interval |

Environment variables:
```
METRICS_SERVICE_HOST=0.0.0.0
METRICS_SERVICE_PORT=8890
OTEL_PROMETHEUS_ENABLED=true
OTEL_PROMETHEUS_PORT=9465
METRICS_RATE_LIMIT=5000
SQLITE_DB_PATH=/tmp/metrics.db  # Ephemeral, not persisted
METRICS_API_KEY_REGISTRY=<from MetricsApiKey parameter>  # API key for registry/auth-server authentication
```

### ADOT Collector

AWS Distro for OpenTelemetry collector configuration:

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'mcp-metrics-service'
          scrape_interval: 15s
          static_configs:
            - targets: ['metrics-service.internal:9465']

exporters:
  awsprometheusremotewrite:
    endpoint: https://aps-workspaces.${region}.amazonaws.com/workspaces/${workspace_id}/api/v1/remote_write
    aws_auth:
      service: aps
      region: ${region}

service:
  pipelines:
    metrics:
      receivers: [prometheus]
      exporters: [awsprometheusremotewrite]
```

### Grafana OSS

Pre-configured Grafana container:

| Configuration | Value |
|--------------|-------|
| Image | `${ECR}/mcp-gateway-grafana:latest` |
| CPU | 512 |
| Memory | 1024 |
| Port | 3000 |
| Root URL | `/grafana/` |
| Auth | Anonymous (Admin role) |

**Critical Environment Variables for SigV4 Authentication:**

For Grafana to authenticate to Amazon Managed Prometheus (AMP), these environment variables are required:

| Variable | Value | Purpose |
|----------|-------|---------|
| `AWS_REGION` | `${AWS::Region}` | AWS region for SDK |
| `AWS_DEFAULT_REGION` | `${AWS::Region}` | Fallback region for SDK |
| `AWS_SDK_LOAD_CONFIG` | `1` | Enables AWS SDK config loading for ECS credential discovery |
| `GF_AUTH_SIGV4_AUTH_ENABLED` | `true` | **Required** - Enables SigV4 signing for AWS datasources |

**Important**: Without `GF_AUTH_SIGV4_AUTH_ENABLED=true`, Grafana will not sign requests to AMP even if `sigV4Auth: true` is set in the datasource configuration. This is per [AWS documentation](https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-onboard-query-standalone-grafana.html).

Datasources (provisioned):
1. **Amazon Managed Prometheus** - Default, SigV4 auth
2. **CloudWatch** - ECS Container Insights metrics

Dashboards (provisioned):
1. **MCP Analytics Comprehensive** - 19 panels covering MCP protocol metrics
2. **AWS Infrastructure** - 11 panels for ECS/ALB/CloudWatch metrics

## Metric Types Collected

### Authentication Metrics
- `mcp_auth_requests_total` - Counter by success, method, server
- `mcp_auth_request_duration_seconds` - Histogram of auth latency

### Tool Execution Metrics
- `mcp_tool_executions_total` - Counter by tool, server, success
- `mcp_tool_execution_duration_seconds` - Histogram of execution time

### Discovery Metrics
- `mcp_tool_discovery_total` - Counter of semantic search requests
- `mcp_discovery_duration_seconds` - Histogram of search latency

### Protocol Flow Metrics
- `mcp_protocol_latency_seconds` - Time between protocol steps
  - initialize → tools/list
  - tools/list → tools/call
  - initialize → tools/call (full flow)

## Security Considerations

### Network Security
- metrics-service is deployed in private subnets
- Only accessible via internal ALB or service discovery
- No public internet exposure

### Authentication
- Service-to-metrics-service: API key authentication
- ADOT-to-AMP: IAM role with SigV4
- Grafana-to-AMP: IAM task role with SigV4
- User-to-Grafana: Anonymous access (workshop) or can be configured for auth

### IAM Roles

**metrics-service Task Role**:
- No special permissions required (stateless)

**ADOT Task Role**:
```json
{
  "Effect": "Allow",
  "Action": [
    "aps:RemoteWrite"
  ],
  "Resource": "arn:aws:aps:region:account:workspace/workspace-id"
}
```

**Grafana Task Role**:
```json
{
  "Effect": "Allow",
  "Action": [
    "aps:QueryMetrics",
    "aps:GetMetricMetadata",
    "aps:GetSeries",
    "aps:GetLabels"
  ],
  "Resource": "arn:aws:aps:region:account:workspace/workspace-id"
}
```

## Cost Considerations

| Component | Estimated Monthly Cost | Notes |
|-----------|----------------------|-------|
| AMP | $0.90/10M samples ingested | ~$5-10/month for workshop |
| metrics-service (Fargate) | ~$10/month | 256 CPU, 512 MB |
| ADOT (Fargate) | ~$10/month | 256 CPU, 512 MB |
| Grafana OSS (Fargate) | ~$10/month | 256 CPU, 512 MB |
| **Total** | **~$35-40/month** | For observability stack |

Note: Amazon Managed Grafana (AMG) was considered but requires SAML/SSO configuration, adding complexity for workshop users. Grafana OSS on ECS provides equivalent functionality with simpler setup.

## Alternatives Not Chosen

### Amazon Managed Grafana (AMG)
- Requires SAML identity provider configuration
- Adds authentication complexity for workshop
- Higher cost (~$9/editor/month + $5/viewer/month)
- Decided: Use Grafana OSS with anonymous access for workshop simplicity

### CloudWatch Only
- Less powerful querying (no PromQL)
- Would require rewriting all dashboards
- Inconsistent with local development experience
- Decided: Use AMP + Grafana for consistency

### Direct OTEL Instrumentation
- Requires code changes to registry and auth-server
- Different pattern than documented local setup
- Would need to maintain two metrics approaches
- Decided: Keep metrics-service pattern for consistency

## Implementation Checklist

- [x] Create Grafana OSS container with pre-configured dashboards
- [x] Add Grafana build to CodeBuild buildspec
- [x] Update observability-stack.yaml with Grafana ECS resources
- [x] Add CloudFront cache behavior for /grafana/*
- [x] Add metrics-service to CloudFormation deployment
- [x] Configure ADOT to scrape metrics-service
- [x] Add METRICS_SERVICE_URL to registry/auth-server task definitions
- [x] Configure API key authentication for metrics-service
- [ ] Test end-to-end metrics flow
- [ ] Validate dashboards show data from AMP

## References

- [MCP Gateway Metrics Architecture](../../../docs/metrics-architecture.md)
- [metrics-service Deployment Guide](../../../metrics-service/docs/deployment.md)
- [metrics-service API Reference](../../../metrics-service/docs/api-reference.md)
- [AWS ADOT Documentation](https://aws-otel.github.io/docs/introduction)
- [Amazon Managed Prometheus User Guide](https://docs.aws.amazon.com/prometheus/latest/userguide/)
