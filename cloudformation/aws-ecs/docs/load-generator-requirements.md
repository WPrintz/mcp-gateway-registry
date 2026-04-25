# Load Generator Requirements

*Created: 2026-01-26*
*Updated: 2026-02-04*
*Purpose: Define load generation strategy to populate Grafana dashboards*

**Status: ✅ IMPLEMENTED** - Enhanced load generator deployed with comprehensive tool coverage and semantic search.

---

## Overview

The Grafana dashboards require active traffic to display meaningful metrics. This document defines what load should be generated to populate all dashboard panels effectively.

**Scope:** This document covers both MCP Server operations and A2A Agent operations, as the platform supports both protocols.

---

## Dashboard Inventory

### MCP Analytics Dashboard (19 panels)

Source: `cloudformation/aws-ecs/grafana/dashboards/mcp-analytics-comprehensive.json`

This dashboard visualizes MCP protocol activity and requires Prometheus metrics from AMP.

| Panel | Title | Metric Required | Labels Needed |
|-------|-------|-----------------|---------------|
| 1 | Real-time Protocol Activity | `mcp_tool_executions_total`, `mcp_auth_requests_total` | method, success |
| 2 | Authentication Flow Analysis | `mcp_auth_requests_total` | success |
| 3 | Authentication Success Rate | `mcp_auth_requests_total` | success |
| 4 | Active MCP Servers | `mcp_tool_executions_total` | server_name |
| 5 | Tool Executions per Hour | `mcp_tool_executions_total` | - |
| 6 | Most Popular Tool | `mcp_tool_executions_total` | tool_name |
| 7 | Protocol Latency Analysis | `mcp_auth_request_duration_seconds_bucket`, `mcp_tool_execution_duration_seconds_bucket` | - |
| 8 | Request Volume Over Time | `mcp_tool_executions_total` | method |
| 9 | Error Rate Analysis | `mcp_auth_requests_total`, `mcp_tool_executions_total` | success |
| 10 | Average Response Times | `mcp_auth_request_duration_seconds_*`, `mcp_tool_execution_duration_seconds_*` | - |
| 11 | Server Performance Dashboard | `mcp_tool_executions_total` | server_name |
| 12 | Tool Usage Rankings | `mcp_tool_executions_total` | tool_name |
| 13 | MCP Protocol Methods Distribution | `mcp_tool_executions_total` | method |
| 14 | Tool Usage by Call Count | `mcp_tool_executions_total` | tool_name |
| 15 | Client Applications Distribution | `mcp_tool_executions_total` | client_name |
| 16 | MCP Protocol Flow Analysis | `mcp_tool_executions_total` | client_name, method |
| 17 | Authentication Methods Distribution | `mcp_auth_requests_total` | method |
| 18 | Request Size Distribution | `mcp_tool_executions_total` | - |
| 19 | Session Activity by Client | `mcp_tool_executions_total` | client_name |

### AWS Infrastructure Dashboard (11 panels)

Source: `cloudformation/aws-ecs/grafana/dashboards/aws-infrastructure.json`

This dashboard uses CloudWatch metrics and auto-populates from HTTP traffic.

| Panel | Title | CloudWatch Namespace | Metric |
|-------|-------|---------------------|--------|
| 1 | ECS Service CPU Utilization | AWS/ECS | CPUUtilization |
| 2 | ECS Service Memory Utilization | AWS/ECS | MemoryUtilization |
| 3 | ALB Request Count | AWS/ApplicationELB | RequestCount |
| 4 | ALB Target Response Time | AWS/ApplicationELB | TargetResponseTime |
| 5 | ALB HTTP Response Codes | AWS/ApplicationELB | HTTPCode_Target_2XX/4XX/5XX_Count |
| 6 | DocumentDB Connections | AWS/DocDB | DatabaseConnections |
| 7 | DocumentDB CPU Utilization | AWS/DocDB | CPUUtilization |
| 8 | DocumentDB Freeable Memory | AWS/DocDB | FreeableMemory |
| 9 | Aurora Serverless ACU | AWS/RDS | ServerlessDatabaseCapacity |
| 10 | ECS Running Task Count | ECS/ContainerInsights | RunningTaskCount |
| 11 | ALB Healthy Hosts | AWS/ApplicationELB | HealthyHostCount |

---

## Dashboard Gap: A2A Agent Analytics

The current MCP Analytics dashboard focuses on MCP server/tool metrics. **Agent-specific panels should be added** to track A2A protocol activity.

### Recommended Agent Dashboard Panels

| Panel | Title | Metric | Labels |
|-------|-------|--------|--------|
| A1 | Agent Discovery Rate | `a2a_agent_discovery_total` | query_type (skills/semantic) |
| A2 | Agent Invocations | `a2a_agent_invocations_total` | agent_path, skill_name, success |
| A3 | Active Agents | `a2a_agent_active_count` | - |
| A4 | Agent Health Check Results | `a2a_agent_health_checks_total` | agent_path, status |
| A5 | Agent Registration Rate | `a2a_agent_registrations_total` | visibility |
| A6 | Agent Latency (P95/P99) | `a2a_agent_invocation_duration_seconds_bucket` | agent_path |
| A7 | Popular Agents by Invocation | `a2a_agent_invocations_total` | agent_path |
| A8 | Skill Usage Distribution | `a2a_agent_invocations_total` | skill_name |
| A9 | Agent Error Rate | `a2a_agent_invocations_total` | success |
| A10 | Agent Security Scan Results | `a2a_agent_security_scans_total` | result (safe/unsafe) |

### TODO: Extend Dashboard

The `mcp-analytics-comprehensive.json` dashboard should be extended to include agent panels. Consider either:
1. Adding agent panels to the existing dashboard (preferred for unified view)
2. Creating a separate `a2a-agent-analytics.json` dashboard

---

## Required Prometheus Metrics

### MCP Server Metrics

The MCP Analytics dashboard expects these metric families:

### MCP Counter Metrics

```prometheus
# MCP tool/protocol executions
mcp_tool_executions_total{method, success, server_name, tool_name, client_name}

# Authentication requests
mcp_auth_requests_total{success, method}
```

### MCP Histogram Metrics

```prometheus
# Auth request latency distribution
mcp_auth_request_duration_seconds_bucket{le}
mcp_auth_request_duration_seconds_sum
mcp_auth_request_duration_seconds_count

# Tool execution latency distribution
mcp_tool_execution_duration_seconds_bucket{le}
mcp_tool_execution_duration_seconds_sum
mcp_tool_execution_duration_seconds_count
```

### A2A Agent Metrics (Proposed)

These metrics should be instrumented in the registry to track agent operations:

```prometheus
# Agent discovery requests
a2a_agent_discovery_total{query_type, success}
# query_type: "skills", "semantic", "list"

# Agent invocations (when agents are called via gateway)
a2a_agent_invocations_total{agent_path, skill_name, success, client_name}

# Agent health checks
a2a_agent_health_checks_total{agent_path, status}
# status: "healthy", "unhealthy", "timeout"

# Agent registrations
a2a_agent_registrations_total{visibility, success}
# visibility: "public", "private", "group-restricted"

# Agent management operations
a2a_agent_operations_total{operation, success}
# operation: "register", "update", "delete", "toggle", "rate"

# Agent security scans
a2a_agent_security_scans_total{result}
# result: "safe", "unsafe", "error"
```

### A2A Agent Histogram Metrics (Proposed)

```prometheus
# Agent invocation latency
a2a_agent_invocation_duration_seconds_bucket{agent_path, le}
a2a_agent_invocation_duration_seconds_sum{agent_path}
a2a_agent_invocation_duration_seconds_count{agent_path}

# Agent discovery latency
a2a_agent_discovery_duration_seconds_bucket{query_type, le}
```

---

## Load Generation Strategy

### Implementation Status: ✅ COMPLETE (2026-02-04)

**Location:** `cloudformation/aws-ecs/scripts/load-generator.sh`

The load generator has been implemented as a bash script with the following capabilities:

### 1. MCP Protocol Operations ✅

Exercises all MCP protocol methods with comprehensive tool coverage:

| Method | Implementation | Coverage |
|--------|----------------|----------|
| `initialize` | ✅ Implemented | All 3 servers |
| `tools/list` | ✅ Implemented | All 3 servers |
| `tools/call` | ✅ Implemented | 12 unique tools across servers |

**Tool Coverage by Server:**

| Server | Tools Exercised | Arguments |
|--------|-----------------|-----------|
| `currenttime` | `current_time_by_timezone` | 5 timezone variations |
| `mcpgw` | `list_services`, `get_http_headers`, `healthcheck`, `intelligent_tool_finder`, `list_groups` | Realistic queries |
| `realserverfaketools` | `quantum_flux_analyzer`, `neural_pattern_synthesizer`, `hyper_dimensional_mapper`, `temporal_anomaly_detector`, `user_profile_analyzer`, `synthetic_data_generator` | Test data with proper schemas |

**Traffic Distribution:**
- 50% Full flow (initialize → tools/list → tools/call)
- 30% Direct tool calls (established sessions)
- 20% Discovery only (initialize + list)

### 2. MCP Server Search ✅

Semantic search functionality implemented via `/api/servers/search`:

**Search Queries:**
- "time and date operations"
- "gateway management tools"
- "registry administration"
- "fake tools for testing"
- "quantum analysis"
- "neural network tools"
- "timezone conversion"

**Traffic:** 10% of total load

### 3. A2A Agent Operations ✅

Agent API endpoints exercised:

| Operation | Endpoint | Traffic % |
|-----------|----------|-----------|
| List agents | `GET /api/agents` | 40% |
| Skill discovery | `POST /api/agents/discover` | 20% |
| Semantic discovery | `POST /api/agents/discover/semantic` | 20% |
| Get details | `GET /api/agents/{path}` | 10% |
| Health check | `POST /api/agents/{path}/health` | 10% |

### 4. Overall Traffic Distribution

- **60% MCP operations** (initialize, tools/list, tools/call)
- **30% Agent operations** (list, discover, health)
- **10% Server search** (semantic search)

### 5. Client Identity Variation ✅

Multiple client names for metrics dimension:
- `load-generator-primary`
- `load-generator-secondary`
- `workshop-demo-client`

### 6. Authentication ✅

- M2M OAuth2 flow via Keycloak
- Automatic token refresh (before 5min expiry)
- Client credentials grant

---

## Load Generation Strategy (Original Requirements)

---

## A2A Agent Load Generation

### Implementation Status: ✅ COMPLETE (2026-02-04)

The load generator exercises the following agent endpoints:

| Endpoint | Method | Implemented | Traffic % |
|----------|--------|-------------|-----------|
| `/api/agents` | GET | ✅ | 40% |
| `/api/agents/{path}` | GET | ✅ | 10% |
| `/api/agents/{path}/health` | POST | ✅ | 10% |
| `/api/agents/discover` | POST | ✅ | 20% |
| `/api/agents/discover/semantic` | POST | ✅ | 20% |
| `/api/agents/register` | POST | ❌ Not implemented | - |
| `/api/agents/{path}/toggle` | POST | ❌ Not implemented | - |
| `/api/agents/{path}/rate` | POST | ❌ Not implemented | - |

**Note:** Registration, toggle, and rating operations not included to avoid modifying registry state during load testing.

### Agent API Endpoints (Original Requirements)

The load generator should exercise these agent management endpoints:

| Endpoint | Method | Purpose | Panels Populated |
|----------|--------|---------|------------------|
| `/api/agents` | GET | List agents | A3 |
| `/api/agents/register` | POST | Register agent | A5 |
| `/api/agents/{path}` | GET | Get agent details | A2 |
| `/api/agents/{path}` | PUT | Update agent | A2 |
| `/api/agents/{path}` | DELETE | Delete agent | A2 |
| `/api/agents/{path}/health` | POST | Health check | A4 |
| `/api/agents/{path}/toggle` | POST | Enable/disable | A2 |
| `/api/agents/{path}/rate` | POST | Rate agent | A2 |
| `/api/agents/discover` | POST | Skill-based discovery | A1, A8 |
| `/api/agents/discover/semantic` | POST | Semantic search | A1 |
| `/api/agents/{path}/security-scan` | GET | Get scan results | A10 |
| `/api/agents/{path}/rescan` | POST | Trigger scan | A10 |

### Agent Operations Traffic Pattern

```
Agent Traffic Distribution:
- 40% GET /api/agents (list)
- 25% POST /api/agents/discover (skill-based)
- 15% POST /api/agents/discover/semantic
- 10% GET /api/agents/{path} (get details)
- 5%  POST /api/agents/{path}/health
- 5%  Other operations (rate, toggle, etc.)
```

### Target Agents

Exercise all deployed A2A agents:

| Agent | Path | Skills |
|-------|------|--------|
| Flight Booking Agent | `/flight-booking-agent` | book_flight, search_flights, cancel_booking |
| Travel Assistant Agent | `/travel-assistant-agent` | plan_trip, find_hotels, get_recommendations |

### Agent Discovery Scenarios

The load generator should include realistic discovery patterns:

**Skill-based Discovery:**
```json
POST /api/agents/discover
{
  "skills": ["book_flight", "search_flights"],
  "tags": ["travel"],
  "max_results": 10
}
```

**Semantic Discovery:**
```json
POST /api/agents/discover/semantic
{
  "query": "I need an agent that can help me book flights and hotels",
  "max_results": 10
}
```

### Agent Health Check Pattern

Periodically health check all registered agents:

```
Every 60 seconds:
  For each registered agent:
    POST /api/agents/{path}/health
```

---

## Load Generator Implementation

### Status: ✅ DEPLOYED (2026-02-04)

**Implementation:** Bash script at `cloudformation/aws-ecs/scripts/load-generator.sh`

### Usage

```bash
# Set environment variables
export REGISTRY_URL="https://d27uyeutt0mz5g.cloudfront.net"
export KEYCLOAK_URL="https://d2cruktwq9x7li.cloudfront.net"
export CLIENT_ID="mcp-gateway-m2m"
export CLIENT_SECRET="<from-secrets-manager>"
export DURATION=300  # seconds
export RATE=5        # requests per second

# Run load generator
./cloudformation/aws-ecs/scripts/load-generator.sh
```

### Key Features

- **OAuth2 M2M Authentication:** Automatic token management with refresh
- **MCP Protocol Support:** JSON-RPC over HTTP with proper headers
- **Configurable Traffic Patterns:** Adjustable rate and duration
- **Multiple Client Identities:** Rotates through 3 client names
- **Comprehensive Tool Coverage:** 12 unique tools across 3 servers
- **Semantic Search:** Tests both server and agent search endpoints

### Architecture

```
load-generator.sh
├── Token Management (OAuth2 M2M)
├── MCP Operations (60%)
│   ├── initialize (20%)
│   ├── tools/list (20%)
│   └── tools/call (60%)
├── Agent Operations (30%)
│   ├── list (40%)
│   ├── discover/skills (20%)
│   ├── discover/semantic (20%)
│   ├── get details (10%)
│   └── health check (10%)
└── Server Search (10%)
    └── semantic search
```

### Deployment Options

**Current:** Local/bastion execution (implemented)
**Future:** ECS Fargate task for continuous load (not implemented)

---

## Load Generator Implementation (Original Requirements)

### Recommended Approach

A Python-based load generator is recommended because:
1. OAuth2 M2M authentication support
2. MCP protocol (JSON-RPC over HTTP/SSE) handling
3. Configurable traffic patterns
4. Easy integration with existing test scripts

### Key Components

```
load-generator/
├── config.yaml           # Traffic patterns, rates, targets
├── load_generator.py     # Main orchestrator
├── auth_client.py        # OAuth2 token management
├── mcp_client.py         # MCP protocol client
└── scenarios/
    ├── protocol_flow.py  # initialize -> tools/list -> tools/call
    ├── tool_calls.py     # Random tool execution
    └── auth_stress.py    # Auth-focused load
```

### Configuration Example

```yaml
load_generator:
  rate: 10  # requests per second
  duration: 3600  # seconds (1 hour)

targets:
  registry_url: "https://d1fr5xu1m4op3j.cloudfront.net"
  keycloak_url: "https://d1yq0pbg4lerej.cloudfront.net"

servers:
  - name: currenttime
    tools: [get_current_time]
  - name: mcpgw
    tools: [list_servers, get_server_info]
  - name: realserverfaketools
    tools: [fake_tool_1, fake_tool_2]

clients:
  - name: load-generator-primary
    weight: 60
  - name: load-generator-secondary
    weight: 30
  - name: workshop-demo-client
    weight: 10

auth:
  client_id: registry-admin-bot
  token_refresh_interval: 240  # seconds (before 5min expiry)

mcp_scenarios:
  - name: protocol_flow
    weight: 40
    steps: [initialize, tools/list, tools/call]
  - name: tool_stress
    weight: 50
    steps: [tools/call]  # random tools
  - name: discovery
    weight: 10
    steps: [tools/list]

agents:
  - path: /flight-booking-agent
    skills: [book_flight, search_flights, cancel_booking]
  - path: /travel-assistant-agent
    skills: [plan_trip, find_hotels, get_recommendations]

agent_scenarios:
  - name: agent_list
    weight: 40
    endpoint: GET /api/agents
  - name: skill_discovery
    weight: 25
    endpoint: POST /api/agents/discover
    skills: [book_flight, plan_trip]
  - name: semantic_discovery
    weight: 15
    endpoint: POST /api/agents/discover/semantic
    queries:
      - "find an agent to book flights"
      - "help me plan a vacation"
      - "travel booking assistant"
  - name: agent_details
    weight: 10
    endpoint: GET /api/agents/{path}
  - name: health_check
    weight: 5
    endpoint: POST /api/agents/{path}/health
  - name: rate_agent
    weight: 5
    endpoint: POST /api/agents/{path}/rate
```

### Traffic Patterns

**Steady State:**
```
Rate: 10 req/sec
Duration: Continuous
Pattern: Random distribution across servers/tools
```

**Burst Mode:**
```
Rate: 50 req/sec
Duration: 60 seconds
Interval: Every 10 minutes
Purpose: Test scaling and latency under load
```

**Realistic Session:**
```
1. Initialize connection
2. List available tools
3. Call 3-5 tools
4. Wait 30-60 seconds
5. Call 1-2 more tools
6. Repeat from step 3
```

---

## Deployment Options

### Option 1: ECS Fargate Task

Deploy as a scheduled or long-running ECS task:

```yaml
# Add to services-stack.yaml or separate load-generator-stack.yaml
LoadGeneratorTaskDefinition:
  Type: AWS::ECS::TaskDefinition
  Properties:
    Family: mcp-gateway-load-generator
    Cpu: 256
    Memory: 512
    ContainerDefinitions:
      - Name: load-generator
        Image: !Sub "${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/mcp-gateway-load-generator:latest"
        Environment:
          - Name: REGISTRY_URL
            Value: !ImportValue RegistryUrl
          - Name: KEYCLOAK_URL
            Value: !ImportValue KeycloakCloudFrontUrl
          - Name: RATE
            Value: "10"
```

### Option 2: Local/Bastion Execution

Run from local machine or bastion host:

```bash
# Get M2M token
./api/get-m2m-token.sh \
  --aws-region us-west-2 \
  --keycloak-url https://d1yq0pbg4lerej.cloudfront.net \
  --output-file .token \
  registry-admin-bot

# Run load generator
python load_generator.py \
  --config config.yaml \
  --token-file .token \
  --duration 3600
```

### Option 3: Simple Bash Loop

Lightweight option using existing test scripts:

```bash
#!/bin/bash
# simple-load-generator.sh

REGISTRY_URL="https://d1fr5xu1m4op3j.cloudfront.net"
TOKEN=$(cat .token)
SERVERS=("currenttime" "mcpgw" "realserverfaketools")
AGENTS=("/flight-booking-agent" "/travel-assistant-agent")
SKILLS=("book_flight" "search_flights" "plan_trip" "find_hotels")
QUERIES=("book a flight" "plan vacation" "travel assistant" "hotel booking")

while true; do
  # Randomly choose between MCP and Agent operations (70/30 split)
  if [ $((RANDOM % 10)) -lt 7 ]; then
    # MCP Protocol operations (70%)
    SERVER=${SERVERS[$RANDOM % ${#SERVERS[@]}]}

    curl -s -X POST "$REGISTRY_URL/mcp/$SERVER/" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"initialize","id":1}'

    curl -s -X POST "$REGISTRY_URL/mcp/$SERVER/" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
  else
    # Agent operations (30%)
    AGENT=${AGENTS[$RANDOM % ${#AGENTS[@]}]}
    SKILL=${SKILLS[$RANDOM % ${#SKILLS[@]}]}
    QUERY=${QUERIES[$RANDOM % ${#QUERIES[@]}]}

    # List agents
    curl -s -X GET "$REGISTRY_URL/api/agents" \
      -H "Authorization: Bearer $TOKEN"

    # Skill-based discovery
    curl -s -X POST "$REGISTRY_URL/api/agents/discover" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"skills\":[\"$SKILL\"],\"max_results\":5}"

    # Semantic discovery
    curl -s -X POST "$REGISTRY_URL/api/agents/discover/semantic" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"query\":\"$QUERY\",\"max_results\":5}"

    # Get agent details
    curl -s -X GET "$REGISTRY_URL/api/agents$AGENT" \
      -H "Authorization: Bearer $TOKEN"

    # Health check (every ~10th iteration)
    if [ $((RANDOM % 10)) -eq 0 ]; then
      curl -s -X POST "$REGISTRY_URL/api/agents$AGENT/health" \
        -H "Authorization: Bearer $TOKEN"
    fi
  fi

  # Rate limiting
  sleep 0.1  # 10 req/sec
done
```

---

## Verification

### Check MCP Metrics in AMP

Query AMP workspace to verify MCP metrics are being collected:

```promql
# Total tool executions
sum(mcp_tool_executions_total)

# Executions by server
sum(mcp_tool_executions_total) by (server_name)

# Auth requests
sum(mcp_auth_requests_total) by (success)

# Request rate
sum(rate(mcp_tool_executions_total[5m]))
```

### Check Agent Metrics in AMP

Query AMP workspace to verify agent metrics (once instrumented):

```promql
# Total agent discovery requests
sum(a2a_agent_discovery_total)

# Discovery by type
sum(a2a_agent_discovery_total) by (query_type)

# Agent health check results
sum(a2a_agent_health_checks_total) by (status)

# Agent operations
sum(a2a_agent_operations_total) by (operation)
```

### Check CloudWatch Metrics

Verify ALB and ECS metrics are populating:

```bash
# ALB request count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/mcp-gateway-alb/xxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Sum
```

### Grafana Dashboard Validation

After running load generator for 5+ minutes:

1. Open Grafana at `https://<cloudfront>/grafana/`
2. Navigate to "MCP Gateway - Analytics Dashboard"
3. Verify MCP panels show data:
   - Real-time Protocol Activity (panel 1) - time series with lines
   - Authentication Flow Analysis (panel 2) - success/failure rates
   - Active MCP Servers (panel 4) - count > 0
   - Tool Executions per Hour (panel 5) - increasing counter
   - Server Performance Dashboard (panel 11) - table with rows
4. Verify Agent panels show data (once dashboard extended):
   - Agent Discovery Rate (panel A1) - requests per minute
   - Active Agents (panel A3) - count > 0
   - Agent Health Check Results (panel A4) - healthy/unhealthy counts
   - Skill Usage Distribution (panel A8) - bar chart with data

---

## Notes

### Metrics Pipeline Dependency

The load generator only generates HTTP traffic. For metrics to reach Grafana:

1. **Application must instrument metrics** - Registry/auth-server must expose Prometheus metrics
2. **metrics-service must aggregate** - Centralized metrics endpoint
3. **ADOT must scrape** - Collector pulls from metrics-service
4. **AMP must store** - Remote write to AMP workspace
5. **Grafana must query** - SigV4 auth to AMP

If dashboards remain empty after load generation, check each step in the pipeline.

### Current Gap

As of 2026-01-26, the metrics-service is not yet deployed to CloudFormation. The application instrumentation exists but metrics are not being collected. See `observability-architecture.md` for the full architecture and Phase 1.5 tasks in the steering log.

---

## Action Items Summary

### Prerequisites (Before Load Generator)

| Item | Status | Notes |
|------|--------|-------|
| Deploy metrics-service | ✅ DONE | Deployed and receiving metrics |
| Configure ADOT to scrape metrics-service | ✅ DONE | Scraping every 15s, remote write to AMP |
| Add agent metrics instrumentation | ⚠️ PARTIAL | Basic metrics exist, A2A-specific metrics TODO |
| Extend Grafana dashboard with agent panels | ❌ TODO | Add panels A1-A10 |

### Load Generator Tasks

| Item | Priority | Status | Notes |
|------|----------|--------|-------|
| Create load generator script/service | High | ✅ DONE | Bash implementation complete |
| Add MCP protocol scenarios | High | ✅ DONE | All 3 methods implemented |
| Add Agent API scenarios | High | ✅ DONE | 5 endpoints covered |
| Add MCP server search | Medium | ✅ DONE | Semantic search implemented |
| Deploy as ECS task (optional) | Medium | ❌ TODO | For continuous load |
| Add to workshop deployment automation | Low | ❌ TODO | For demo purposes |

### Dashboard Tasks

| Item | Priority | Status | Notes |
|------|----------|--------|-------|
| Add agent discovery rate panel | High | ❌ TODO | Panel A1 |
| Add agent invocations panel | High | ❌ TODO | Panel A2 |
| Add agent health check panel | Medium | ❌ TODO | Panel A4 |
| Add skill usage distribution | Medium | ❌ TODO | Panel A8 |
| Add agent security scan panel | Low | ❌ TODO | Panel A10 |

---

## Testing and Validation

### Initial Testing (2026-02-04)

**Test Run:** 30 seconds at 5 req/s
- Total requests: 52
- MCP operations: 24 (46%)
- Agent operations: 26 (50%)
- Server search: 2 (4%)
- Status: ✅ Success, no errors

### Recommended Testing Plan

1. **Short Validation (5 minutes)**
   - Verify all endpoints responding
   - Check token refresh working
   - Confirm metrics appearing in Grafana

2. **Extended Load (30-60 minutes)**
   - Populate dashboard with sufficient data
   - Test at higher rates (10+ req/s)
   - Monitor for any errors or failures

3. **Dashboard Validation**
   - Verify all 3 MCP servers visible
   - Confirm tool variety in metrics
   - Check client name distribution
   - Validate agent operations recorded

### Known Limitations

- Actual rate lower than configured (due to curl latency)
- No error injection scenarios
- No state-modifying operations (register, toggle, rate)
- Sequential execution (no parallelism)

---

## References

- [Observability Architecture](./observability-architecture.md) - Full metrics pipeline design
- [Agent API Routes](../../../registry/api/agent_routes.py) - A2A agent endpoint definitions
- [E2E Test Scripts](../../../api/test-management-api-e2e.sh) - Example API calls
- [MCP Client Test](../../../api/test-mcp-client.sh) - MCP protocol examples
- [Load Generator Script](../scripts/load-generator.sh) - Implementation
- [Session Handoff](../../../.scratchpad/session-handoff.md) - Current deployment status
