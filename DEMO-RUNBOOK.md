# MCP Gateway Registry Demo - Runbook

**Purpose**: Quick start guide for demonstrating the MCP Gateway Registry with metrics and load generation.

**Target Audience**: LLM agents running the demo

**Prerequisites**: 
- All services have been set up previously (`.env` configured, Keycloak initialized)
- Docker and Docker Compose are installed and running
- Current working directory is the repository root

---

## Step 1: Start All Services

**Command to run:**
```bash
docker-compose up -d
```

**Expected behavior:**
- All containers start in detached mode
- Takes 30-60 seconds for all services to be healthy
- Keycloak takes the longest (~30 seconds) to initialize

**Verification:**
```bash
docker-compose ps
```

**Expected output:**
- All services should show status "Up" or "Up (healthy)"
- Key services: registry, auth-server, metrics-service, keycloak, prometheus, grafana

**If services fail to start:**
- Check logs: `docker-compose logs [service-name]`
- Common issue: Port conflicts (check if ports 80, 8080, 3000, 9090 are available)
- Solution: Stop conflicting services or run `docker-compose down` and retry

---

## Step 2: Wait for Services to be Ready

**Command to run:**
```bash
sleep 30
```

**Why:** Keycloak needs time to initialize before accepting authentication requests.

**Verification (optional):**
```bash
curl -f http://localhost:8888/health
```

**Expected output:** HTTP 200 response or `{"status":"healthy"}`

---

## Step 3: Generate Load

**Command to run:**
```bash
bash scripts/generate-load.sh
```

**What this does:**
- Automatically generates Keycloak agent tokens (no manual token generation needed)
- Executes ~65 MCP tool calls across 6 phases:
  - Phase 1: Current Time API (10 calls)
  - Phase 2: Quantum Flux Analyzer (15 calls)
  - Phase 3: Neural Pattern Synthesizer (20 calls)
  - Phase 4: Temporal Anomaly Detector (12 calls)
  - Phase 5: Synthetic Data Generator (8 calls)
  - Phase 6: Gateway tools - list_services and healthcheck (10 calls)

**Expected duration:** 1-2 minutes

**Expected output:**
```
==========================================
MCP Load Generation Script
==========================================

Phase 1: Light load on Current Time API
🔄 Generating load on Current Time API (10 calls, 100ms delay)...
  ✓ 5/10 completed
  ✓ 10/10 completed
✅ Current Time API load generation complete

[... more phases ...]

==========================================
Load generation complete!
Check Grafana dashboard for metrics variation
==========================================
```

**If load generation fails:**
- Check if auth-server is healthy: `docker-compose ps auth-server`
- Check token generation: `./keycloak/setup/generate-agent-token.sh agent-test-agent-m2m`
- View auth-server logs: `docker-compose logs auth-server`

---

## Step 4: Verify Metrics are Flowing

**Command to run:**
```bash
curl -s http://localhost:9465/metrics | grep "mcp_protocol_latency_seconds_count" | head -3
```

**Expected output:**
```
mcp_protocol_latency_seconds_count{flow_step="full_protocol_flow",...} 10.0
mcp_protocol_latency_seconds_count{flow_step="full_protocol_flow",...} 55.0
mcp_protocol_latency_seconds_count{flow_step="full_protocol_flow",...} 10.0
```

**What this means:**
- Metrics are being collected and exposed by the metrics-service
- Numbers show count of protocol flow measurements per server
- If output is empty, wait 10 seconds and retry (metrics may still be processing)

---

## Step 5: Access Grafana Dashboard

**URL:** http://localhost:3000

**Credentials:**
- Username: `admin`
- Password: `admin`

**Dashboard to view:** "MCP Gateway - Analytics Dashboard"

**Key panels to highlight:**
1. **Protocol Latency Analysis (P95/P99)** - Shows latency percentiles
2. **Real-time Protocol Activity** - Request rates over time
3. **Tool Usage Rankings** - Most popular tools
4. **Server Performance Dashboard** - Per-server metrics

**Expected behavior:**
- Graphs should show data from the load generation
- Latency values typically in the 0.5-5 second range
- Tool execution counts should match load generation phases

**If dashboard shows "No Data":**
- Wait 30 seconds for Prometheus to scrape metrics
- Verify Prometheus is scraping: http://localhost:9090/targets
- Check metrics endpoint: `curl http://localhost:9465/metrics`
- Re-run load generation: `bash scripts/generate-load.sh`

---

## Step 6: View Prometheus Metrics (Optional)

**URL:** http://localhost:9090

**Example queries to try:**
```promql
# Protocol latency p95
histogram_quantile(0.95, sum(mcp_protocol_latency_seconds_bucket) by (le))

# Tool execution rate
rate(mcp_tool_executions_total[5m])

# Authentication success rate
sum(mcp_auth_requests_total{success="True"}) / sum(mcp_auth_requests_total) * 100
```

---

## Step 7: Stop Services (When Demo is Complete)

**Command to run:**
```bash
docker-compose down
```

**Expected behavior:**
- All containers stop and are removed
- Networks are removed
- Volumes are preserved (metrics data, Keycloak database)

**To completely clean up (including data):**
```bash
docker-compose down -v
```
**Warning:** This deletes all metrics history and Keycloak configuration.

---

## Quick Reference Commands

```bash
# Start services
docker-compose up -d

# Check service status
docker-compose ps

# Generate load
bash scripts/generate-load.sh

# View logs (all services)
docker-compose logs -f

# View logs (specific service)
docker-compose logs -f metrics-service

# Check metrics endpoint
curl http://localhost:9465/metrics | grep mcp_protocol_latency

# Stop services
docker-compose down

# Restart a specific service
docker-compose restart metrics-service
```

---

## Demo Talking Points

**What to highlight during the demo:**

1. **Multi-server architecture**: Multiple MCP servers running simultaneously (currenttime, realserverfaketools, mcpgw)

2. **Authentication flow**: Keycloak-based OAuth2 authentication with service accounts

3. **Real-time metrics**: Live collection and visualization of:
   - Protocol latency (initialize → tools/list → tools/call)
   - Tool execution counts
   - Authentication success rates
   - Per-server performance

4. **Load generation**: Automated testing across different tool types with varying complexity

5. **Observability stack**: Prometheus + Grafana + OpenTelemetry integration

6. **No manual token management**: Load generation script handles authentication automatically

---

## Troubleshooting

### Services won't start
- **Check**: `docker-compose ps` for error status
- **Solution**: `docker-compose logs [service-name]` to see errors
- **Common fix**: `docker-compose down && docker-compose up -d`

### Grafana shows "No Data"
- **Check**: Prometheus targets at http://localhost:9090/targets
- **Solution**: Wait 30 seconds for scrape interval, or re-run load generation

### Load generation fails with authentication errors
- **Check**: `docker-compose logs auth-server`
- **Solution**: Verify Keycloak is healthy: `docker-compose ps keycloak`
- **Fix**: Restart auth-server: `docker-compose restart auth-server`

### Metrics endpoint returns empty
- **Check**: `docker-compose logs metrics-service`
- **Solution**: Verify OpenTelemetry is configured (look for "Prometheus metrics exporter enabled" in logs)
- **Fix**: Rebuild metrics-service: `docker-compose build metrics-service && docker-compose restart metrics-service`

---

## Success Criteria

**The demo is successful when:**
- ✅ All services show "healthy" status in `docker-compose ps`
- ✅ Load generation completes without errors
- ✅ Grafana dashboard displays metrics with data points
- ✅ Metrics endpoint returns data: `curl http://localhost:9465/metrics | grep mcp_protocol_latency`
- ✅ Prometheus shows all targets as "UP" at http://localhost:9090/targets

---

**End of Runbook**
