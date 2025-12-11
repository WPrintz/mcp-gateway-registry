#!/bin/bash
# Test all MCP servers and tools

source .venv/bin/activate

# Function to get fresh token and run test
test_mcp() {
    local url=$1
    local tool=$2
    local args=$3
    local name=$4
    
    ./keycloak/setup/generate-agent-token.sh agent-test-agent-m2m >/dev/null 2>&1
    source .oauth-tokens/agent-test-agent-m2m.env
    
    echo -n "Testing $name... "
    result=$(python cli/mcp_client.py --url "$url" call --tool "$tool" --args "$args" 2>&1)
    if echo "$result" | grep -q '"isError": false'; then
        echo "✅ PASS"
    else
        echo "❌ FAIL"
        echo "$result" | tail -3
    fi
}

echo "=========================================="
echo "MCP Gateway Tool Tests"
echo "=========================================="

# 1. Current Time API
test_mcp "http://localhost/currenttime/mcp" "current_time_by_timezone" '{"tz_name":"UTC"}' "Current Time API"

# 2. Real Server Fake Tools - quantum_flux_analyzer
test_mcp "http://localhost/realserverfaketools/mcp" "quantum_flux_analyzer" '{"energy_level": 5}' "Quantum Flux Analyzer"

# 3. Real Server Fake Tools - neural_pattern_synthesizer
test_mcp "http://localhost/realserverfaketools/mcp" "neural_pattern_synthesizer" '{"input_patterns": ["alpha", "beta"]}' "Neural Pattern Synthesizer"

# 4. MCP Gateway - list_services
test_mcp "http://localhost/mcpgw/mcp" "list_services" '{}' "MCP Gateway list_services"

# 5. MCP Gateway - healthcheck
test_mcp "http://localhost/mcpgw/mcp" "healthcheck" '{}' "MCP Gateway healthcheck"

# 6. Real Server Fake Tools - temporal_anomaly_detector
test_mcp "http://localhost/realserverfaketools/mcp" "temporal_anomaly_detector" '{"timeframe": {"start": "2025-01-01", "end": "2025-12-31"}}' "Temporal Anomaly Detector"

# 7. Real Server Fake Tools - synthetic_data_generator
test_mcp "http://localhost/realserverfaketools/mcp" "synthetic_data_generator" '{"schema": {"name": "string", "age": "integer"}, "record_count": 5}' "Synthetic Data Generator"

# 8. MCP Gateway - intelligent_tool_finder
test_mcp "http://localhost/mcpgw/mcp" "intelligent_tool_finder" '{"natural_language_query": "get current time", "top_n_tools": 3}' "Intelligent Tool Finder"

echo ""
echo "=========================================="
echo "Tests Complete"
echo "=========================================="
