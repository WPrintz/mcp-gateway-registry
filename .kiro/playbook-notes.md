# MCP Gateway Playbook Notes

## Goal
Create an automated playbook for:
1. Standing up MCP Gateway with prebuilt containers
2. Generating load to populate Grafana metrics

---

## Setup Completed (Build from Source)

### Environment Configuration
- `.env` created with secure passwords (later simplified for local dev)
- `mcp-gateway/` folder is LOCAL to repo (not `${HOME}/mcp-gateway`)
- `docker-compose.yml` updated to use `./mcp-gateway` paths
- `.gitignore` updated to exclude `mcp-gateway/` directory

### Embeddings Model
- Model: `sentence-transformers/all-MiniLM-L6-v2`
- Location: `./mcp-gateway/models/all-MiniLM-L6-v2/`
- Download command: `huggingface-cli download sentence-transformers/all-MiniLM-L6-v2 --local-dir ./mcp-gateway/models/all-MiniLM-L6-v2`

### Keycloak Setup
1. Start services: `docker-compose up -d keycloak-db keycloak`
2. Wait for Keycloak to be ready (~30 seconds)
3. **macOS SSL Fix (CRITICAL):**
   ```bash
   docker exec mcp-gateway-registry-keycloak-1 /opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password "${KEYCLOAK_ADMIN_PASSWORD}"
   docker exec mcp-gateway-registry-keycloak-1 /opt/keycloak/bin/kcadm.sh update realms/master -s sslRequired=NONE
   ```
4. Run init script: `./keycloak/setup/init-keycloak.sh`
5. **Fix mcp-gateway realm SSL:**
   ```bash
   docker exec mcp-gateway-registry-keycloak-1 /opt/keycloak/bin/kcadm.sh update realms/mcp-gateway -s sslRequired=NONE
   ```
6. Get credentials: `./keycloak/setup/get-all-client-credentials.sh`
7. Update `.env` with client secrets from `.oauth-tokens/keycloak-client-secrets.txt`

### Password Setup (Local Dev)
- Use `--temporary=false` flag when setting Keycloak passwords:
  ```bash
  docker exec mcp-gateway-registry-keycloak-1 /opt/keycloak/bin/kcadm.sh set-password -r mcp-gateway --username admin --new-password admin --temporary=false
  docker exec mcp-gateway-registry-keycloak-1 /opt/keycloak/bin/kcadm.sh set-password -r mcp-gateway --username testuser --new-password testuser --temporary=false
  ```

### Scopes Configuration Fix
- **IMPORTANT:** Add `mcp-servers-unrestricted` group mapping to `mcp-gateway/auth_server/scopes.yml`:
  ```yaml
  group_mappings:
    # ... existing mappings ...
    mcp-servers-unrestricted:
    - mcp-servers-unrestricted/read
    - mcp-servers-unrestricted/execute
  ```
- Restart auth-server after changes: `docker-compose restart auth-server`

### Test Agent Setup
```bash
./keycloak/setup/setup-agent-service-account.sh --agent-id test-agent --group mcp-servers-unrestricted
./keycloak/setup/get-all-client-credentials.sh
```

---

## Credentials (Local Dev)

### Web Login
- MCP Gateway Registry: `admin`/`admin` or `testuser`/`testuser`
- Grafana: `admin`/`admin`
- Keycloak Admin Console: `admin`/`${KEYCLOAK_ADMIN_PASSWORD}` (master realm)

### Files
- `.oauth-tokens/keycloak-user-passwords.txt` - Web login credentials
- `.oauth-tokens/keycloak-client-secrets.txt` - Client secrets
- `.oauth-tokens/agent-test-agent-m2m.json` - Agent credentials

---

## MCP Tool Testing

### Generate Token
```bash
./keycloak/setup/generate-agent-token.sh agent-test-agent-m2m
```

### Test Commands
```bash
source .venv/bin/activate
source .oauth-tokens/agent-test-agent-m2m.env

# List tools
python cli/mcp_client.py --url http://localhost/currenttime/mcp list

# Call tool
python cli/mcp_client.py --url http://localhost/currenttime/mcp call --tool current_time_by_timezone --args '{"tz_name":"America/Chicago"}'
```

### Available MCP Servers
| Server | URL | Key Tools |
|--------|-----|-----------|
| Current Time API | http://localhost/currenttime/mcp | `current_time_by_timezone` |
| Real Server Fake Tools | http://localhost/realserverfaketools/mcp | `quantum_flux_analyzer`, etc. |
| MCP Gateway Tools | http://localhost/mcpgw/mcp | `list_services`, etc. |
| Financial Info | http://localhost/fininfo/mcp | `get_stock_aggregates` |

---

## Services & Ports

| Service | URL | Notes |
|---------|-----|-------|
| Registry | http://localhost (80/443/7860) | Main web UI |
| Keycloak | http://localhost:8080 | Identity provider |
| Auth Server | http://localhost:8888 | Token validation |
| Grafana | http://localhost:3000 | Metrics dashboards |
| Prometheus | http://localhost:9090 | Metrics collection |
| Current Time MCP | http://localhost:8000 | Direct access |
| Financial Info MCP | http://localhost:8001 | Direct access |
| Real Server Fake Tools MCP | http://localhost:8002 | Direct access |
| MCP Gateway MCP | http://localhost:8003 | Direct access |
| Atlassian MCP | http://localhost:8005 | Direct access |

---

## TODO for Playbook
- [ ] Create automated startup script for prebuilt containers
- [ ] Create load generation script for Grafana metrics
- [ ] Document simplified password setup
- [ ] Test prebuilt container deployment flow
