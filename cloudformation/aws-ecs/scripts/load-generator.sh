#!/bin/bash
#
# MCP Gateway Load Generator
# Generates traffic to populate Grafana dashboards
#
# Usage:
#   ./load-generator.sh --registry-url https://xxx.cloudfront.net \
#                       --keycloak-url https://xxx.cloudfront.net \
#                       --client-secret <secret> \
#                       --duration 300
#
# CloudShell Quick Start:
#   export REGISTRY_URL="https://d1fr5xu1m4op3j.cloudfront.net"
#   export KEYCLOAK_URL="https://d1yq0pbg4lerej.cloudfront.net"
#   SECRET_JSON=$(aws secretsmanager get-secret-value \
#     --secret-id mcp-gateway-keycloak-m2m-client-secret \
#     --region us-west-2 --query 'SecretString' --output text)
#   export CLIENT_ID=$(echo "$SECRET_JSON" | jq -r '.client_id')
#   export CLIENT_SECRET=$(echo "$SECRET_JSON" | jq -r '.client_secret')
#   ./load-generator.sh

# Don't use set -e as we want to continue on curl failures
set -u  # Exit on undefined variables only

# =============================================================================
# Configuration
# =============================================================================

REGISTRY_URL="${REGISTRY_URL:-}"
KEYCLOAK_URL="${KEYCLOAK_URL:-}"
CLIENT_ID="${CLIENT_ID:-mcp-gateway-m2m}"
CLIENT_SECRET="${CLIENT_SECRET:-}"
DURATION="${DURATION:-300}"
RATE="${RATE:-5}"  # requests per second (sleep interval = 1/RATE)
VERBOSE="${VERBOSE:-false}"

# MCP Servers to exercise
SERVERS=("currenttime" "mcpgw" "realserverfaketools")

# Semantic search queries for MCP servers
SERVER_SEARCH_QUERIES=(
    "time and date operations"
    "gateway management tools"
    "registry administration"
    "fake tools for testing"
    "quantum analysis"
    "neural network tools"
    "timezone conversion"
)

# A2A Agents to exercise
AGENTS=("flight-booking-agent" "travel-assistant-agent")

# Skills for discovery queries
SKILLS=("book_flight" "search_flights" "cancel_booking" "plan_trip" "find_hotels" "get_recommendations")

# Semantic queries for agent discovery
QUERIES=(
    "find an agent to book flights"
    "help me plan a vacation"
    "travel booking assistant"
    "I need to cancel my flight reservation"
    "search for available hotels"
)

# Client names for metrics dimension variation
CLIENT_NAMES=("load-generator-primary" "load-generator-secondary" "workshop-demo-client")

# =============================================================================
# Parse Arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --registry-url)
            REGISTRY_URL="$2"
            shift 2
            ;;
        --keycloak-url)
            KEYCLOAK_URL="$2"
            shift 2
            ;;
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --client-secret)
            CLIENT_SECRET="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --rate)
            RATE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE="true"
            shift
            ;;
        --help|-h)
            echo "MCP Gateway Load Generator"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --registry-url URL    Registry base URL (or set REGISTRY_URL env var)"
            echo "  --keycloak-url URL    Keycloak base URL (or set KEYCLOAK_URL env var)"
            echo "  --client-id ID        OAuth2 client ID (default: registry-admin-bot)"
            echo "  --client-secret SEC   OAuth2 client secret (or set CLIENT_SECRET env var)"
            echo "  --duration SECS       How long to run (default: 300)"
            echo "  --rate RPS            Requests per second (default: 5)"
            echo "  --verbose, -v         Show detailed output"
            echo "  --help, -h            Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# =============================================================================
# Validation
# =============================================================================

if [[ -z "$REGISTRY_URL" ]]; then
    echo "ERROR: --registry-url or REGISTRY_URL env var required"
    exit 1
fi

if [[ -z "$KEYCLOAK_URL" ]]; then
    echo "ERROR: --keycloak-url or KEYCLOAK_URL env var required"
    exit 1
fi

if [[ -z "$CLIENT_SECRET" ]]; then
    echo "ERROR: --client-secret or CLIENT_SECRET env var required"
    echo ""
    echo "Get secret from AWS Secrets Manager:"
    echo "  export CLIENT_SECRET=\$(aws secretsmanager get-secret-value \\"
    echo "    --secret-id mcp-gateway-keycloak-client-secret \\"
    echo "    --query 'SecretString' --output text | jq -r '.client_secret')"
    exit 1
fi

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date '+%H:%M:%S')] DEBUG: $*"
    fi
}

random_element() {
    local arr=("$@")
    echo "${arr[$RANDOM % ${#arr[@]}]}"
}

get_server_tools() {
    local server="$1"
    case "$server" in
        currenttime)
            echo "current_time_by_timezone"
            ;;
        mcpgw)
            echo "list_services get_http_headers healthcheck intelligent_tool_finder list_groups"
            ;;
        realserverfaketools)
            echo "quantum_flux_analyzer neural_pattern_synthesizer hyper_dimensional_mapper temporal_anomaly_detector user_profile_analyzer synthetic_data_generator"
            ;;
        *)
            echo ""
            ;;
    esac
}

# =============================================================================
# Token Management
# =============================================================================

ACCESS_TOKEN=""
TOKEN_EXPIRY=0

get_token() {
    local now
    now=$(date +%s)

    # Refresh token if expired or expiring soon (within 30 seconds)
    if [[ $now -ge $((TOKEN_EXPIRY - 30)) ]]; then
        log "Fetching new access token..."

        local response
        response=$(curl -s -X POST "${KEYCLOAK_URL}/realms/mcp-gateway/protocol/openid-connect/token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "grant_type=client_credentials" \
            -d "client_id=${CLIENT_ID}" \
            -d "client_secret=${CLIENT_SECRET}")

        ACCESS_TOKEN=$(echo "$response" | jq -r '.access_token // empty')
        local expires_in
        expires_in=$(echo "$response" | jq -r '.expires_in // 300')

        if [[ -z "$ACCESS_TOKEN" ]]; then
            echo "ERROR: Failed to get access token"
            echo "Response: $response"
            exit 1
        fi

        TOKEN_EXPIRY=$((now + expires_in))
        log "Token acquired (expires in ${expires_in}s)"
    fi

    echo "$ACCESS_TOKEN"
}

# =============================================================================
# MCP Protocol Operations
# =============================================================================

mcp_initialize() {
    local server="$1"
    local client_name="$2"
    local token
    token=$(get_token)

    debug "MCP initialize: $server (client: $client_name)"

    local body='{
        "jsonrpc": "2.0",
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "'"$client_name"'",
                "version": "1.0.0"
            }
        },
        "id": 1
    }'

    curl -s -X POST "${REGISTRY_URL}/${server}/" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "X-Client-Name: $client_name" \
        -H "X-Body: $(echo "$body" | tr -d '\n' | tr -s ' ')" \
        -d "$body" > /dev/null 2>&1 || true
}

mcp_list_tools() {
    local server="$1"
    local client_name="$2"
    local token
    token=$(get_token)

    debug "MCP tools/list: $server (client: $client_name)"

    local body='{
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": 2
    }'

    curl -s -X POST "${REGISTRY_URL}/${server}/" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "X-Client-Name: $client_name" \
        -H "X-Body: $(echo "$body" | tr -d '\n' | tr -s ' ')" \
        -d "$body" > /dev/null 2>&1 || true
}

mcp_call_tool() {
    local server="$1"
    local tool_name="$2"
    local client_name="$3"
    local token
    token=$(get_token)

    debug "MCP tools/call: $server/$tool_name (client: $client_name)"

    # Tool-specific arguments
    local args='{}'
    case "$tool_name" in
        current_time_by_timezone)
            local timezones=("America/New_York" "Europe/London" "Asia/Tokyo" "UTC" "America/Los_Angeles")
            local tz="${timezones[$RANDOM % ${#timezones[@]}]}"
            args='{"tz_name": "'"$tz"'"}'
            ;;
        quantum_flux_analyzer)
            args='{"energy_level": '$((RANDOM % 10 + 1))'}'
            ;;
        neural_pattern_synthesizer)
            args='{"input_patterns": ["pattern1", "pattern2"]}'
            ;;
        hyper_dimensional_mapper)
            args='{"coordinates": {"latitude": 40.7128, "longitude": -74.0060}}'
            ;;
        temporal_anomaly_detector)
            args='{"timeframe": {"start": "2024-01-01T00:00:00Z", "end": "2024-01-02T00:00:00Z"}}'
            ;;
        user_profile_analyzer)
            args='{"profile": {"user_id": "user123", "name": "Test User", "email": "test@example.com"}}'
            ;;
        synthetic_data_generator)
            args='{"schema": {"type": "object", "properties": {"name": {"type": "string"}}}}'
            ;;
        intelligent_tool_finder)
            local queries=("find time tools" "list all tools" "search for admin tools")
            local query="${queries[$RANDOM % ${#queries[@]}]}"
            args='{"query": "'"$query"'"}'
            ;;
        list_services|get_http_headers|healthcheck|list_groups)
            args='{}'
            ;;
    esac

    local body='{
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "'"$tool_name"'",
            "arguments": '"$args"'
        },
        "id": 3
    }'

    curl -s -X POST "${REGISTRY_URL}/${server}/" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "X-Client-Name: $client_name" \
        -H "X-Body: $(echo "$body" | tr -d '\n' | tr -s ' ')" \
        -d "$body" > /dev/null 2>&1 || true
}

# =============================================================================
# A2A Agent Operations
# =============================================================================

agent_list() {
    local token
    token=$(get_token)

    debug "Agent: list all"

    curl -s -X GET "${REGISTRY_URL}/api/agents" \
        -H "Authorization: Bearer $token" > /dev/null 2>&1 || true
}

agent_get() {
    local agent_path="$1"
    local token
    token=$(get_token)

    debug "Agent: get $agent_path"

    curl -s -X GET "${REGISTRY_URL}/api/agents/${agent_path}" \
        -H "Authorization: Bearer $token" > /dev/null 2>&1 || true
}

agent_discover_skills() {
    local skill="$1"
    local token
    token=$(get_token)

    debug "Agent: discover by skill ($skill)"

    curl -s -X POST "${REGISTRY_URL}/api/agents/discover" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "skills": ["'"$skill"'"],
            "max_results": 5
        }' > /dev/null 2>&1 || true
}

agent_discover_semantic() {
    local query="$1"
    local token
    token=$(get_token)

    debug "Agent: semantic discover ($query)"

    curl -s -X POST "${REGISTRY_URL}/api/agents/discover/semantic" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "query": "'"$query"'",
            "max_results": 5
        }' > /dev/null 2>&1 || true
}

agent_health_check() {
    local agent_path="$1"
    local token
    token=$(get_token)

    debug "Agent: health check $agent_path"

    curl -s -X POST "${REGISTRY_URL}/api/agents/${agent_path}/health" \
        -H "Authorization: Bearer $token" > /dev/null 2>&1 || true
}

# =============================================================================
# MCP Server Search Operations
# =============================================================================

server_search_semantic() {
    local query="$1"
    local token
    token=$(get_token)

    debug "Server: semantic search ($query)"

    curl -s -X POST "${REGISTRY_URL}/api/servers/search" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "query": "'"$query"'",
            "max_results": 5
        }' > /dev/null 2>&1 || true
}

# =============================================================================
# Load Generation Scenarios
# =============================================================================

run_mcp_scenario() {
    local server
    server=$(random_element "${SERVERS[@]}")
    local client_name
    client_name=$(random_element "${CLIENT_NAMES[@]}")

    # Get available tools for this server
    local tools_str
    tools_str=$(get_server_tools "$server")
    local tools_array=($tools_str)
    
    # Randomly choose scenario type
    local scenario=$((RANDOM % 10))
    
    if [[ $scenario -lt 5 ]]; then
        # 50% - Full flow: initialize -> tools/list -> tools/call
        mcp_initialize "$server" "$client_name"
        mcp_list_tools "$server" "$client_name"
        
        if [[ ${#tools_array[@]} -gt 0 ]]; then
            local tool="${tools_array[$RANDOM % ${#tools_array[@]}]}"
            mcp_call_tool "$server" "$tool" "$client_name"
        fi
    elif [[ $scenario -lt 8 ]]; then
        # 30% - Just call a tool (simulating established session)
        if [[ ${#tools_array[@]} -gt 0 ]]; then
            local tool="${tools_array[$RANDOM % ${#tools_array[@]}]}"
            mcp_call_tool "$server" "$tool" "$client_name"
        fi
    else
        # 20% - Discovery only (initialize + list)
        mcp_initialize "$server" "$client_name"
        mcp_list_tools "$server" "$client_name"
    fi
}

run_agent_scenario() {
    local scenario=$((RANDOM % 10))

    case $scenario in
        0|1|2|3)
            # List agents (40% of agent traffic)
            agent_list
            ;;
        4|5)
            # Skill-based discovery (20%)
            local skill
            skill=$(random_element "${SKILLS[@]}")
            agent_discover_skills "$skill"
            ;;
        6|7)
            # Semantic discovery (20%)
            local query
            query=$(random_element "${QUERIES[@]}")
            agent_discover_semantic "$query"
            ;;
        8)
            # Get agent details (10%)
            local agent
            agent=$(random_element "${AGENTS[@]}")
            agent_get "$agent"
            ;;
        9)
            # Health check (10%)
            local agent
            agent=$(random_element "${AGENTS[@]}")
            agent_health_check "$agent"
            ;;
    esac
}

run_server_search_scenario() {
    local query
    query=$(random_element "${SERVER_SEARCH_QUERIES[@]}")
    server_search_semantic "$query"
}

# =============================================================================
# Main Loop
# =============================================================================

main() {
    log "Starting MCP Gateway Load Generator"
    log "Registry URL: $REGISTRY_URL"
    log "Keycloak URL: $KEYCLOAK_URL"
    log "Duration: ${DURATION}s"
    log "Rate: ${RATE} req/s"
    log "Servers: ${SERVERS[*]}"
    log "Agents: ${AGENTS[*]}"
    echo ""

    # Calculate sleep interval
    local sleep_interval
    sleep_interval=$(awk "BEGIN {print 1/$RATE}")

    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + DURATION))
    local request_count=0
    local mcp_count=0
    local agent_count=0

    # Get initial token
    get_token > /dev/null

    log "Load generation started..."

    while [[ $(date +%s) -lt $end_time ]]; do
        # Traffic distribution: 60% MCP, 30% Agent, 10% Server Search
        local rand=$((RANDOM % 10))
        
        if [[ $rand -lt 6 ]]; then
            # 60% MCP operations
            run_mcp_scenario
            ((mcp_count++))
        elif [[ $rand -lt 9 ]]; then
            # 30% Agent operations
            run_agent_scenario
            ((agent_count++))
        else
            # 10% Server search operations
            run_server_search_scenario
        fi

        ((request_count++))

        # Progress report every 50 requests
        if [[ $((request_count % 50)) -eq 0 ]]; then
            local elapsed=$(($(date +%s) - start_time))
            local remaining=$((end_time - $(date +%s)))
            log "Progress: $request_count requests ($mcp_count MCP, $agent_count Agent) | ${elapsed}s elapsed, ${remaining}s remaining"
        fi

        sleep "$sleep_interval"
    done

    echo ""
    log "Load generation complete!"
    log "Total requests: $request_count"
    log "  MCP operations: $mcp_count"
    log "  Agent operations: $agent_count"
    log "Duration: ${DURATION}s"
    log "Actual rate: $(awk -v r="$request_count" -v d="$DURATION" 'BEGIN {printf "%.1f", r/d}') req/s"
}

main
