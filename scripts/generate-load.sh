#!/bin/bash
# Generate variable load on different MCPs for metrics testing

source .venv/bin/activate

# Function to generate load on a specific tool
generate_load() {
    local url=$1
    local tool=$2
    local args=$3
    local iterations=$4
    local delay=$5
    local name=$6
    
    echo "🔄 Generating load on $name ($iterations calls, ${delay}ms delay)..."
    
    for i in $(seq 1 $iterations); do
        ./keycloak/setup/generate-agent-token.sh agent-test-agent-m2m >/dev/null 2>&1
        source .oauth-tokens/agent-test-agent-m2m.env
        
        python cli/mcp_client.py --url "$url" call --tool "$tool" --args "$args" >/dev/null 2>&1 &
        
        if [ $((i % 5)) -eq 0 ]; then
            echo "  ✓ $i/$iterations completed"
        fi
        
        sleep 0.$(printf "%03d" $((RANDOM % 1000)))
    done
    
    wait
    echo "✅ $name load generation complete"
}

echo "=========================================="
echo "MCP Load Generation Script"
echo "=========================================="
echo ""

# Generate variable load patterns
echo "Phase 1: Light load on Current Time API"
generate_load "http://localhost/currenttime/mcp" "current_time_by_timezone" '{"tz_name":"UTC"}' 10 100 "Current Time API"

echo ""
echo "Phase 2: Medium load on Quantum Flux Analyzer"
generate_load "http://localhost/realserverfaketools/mcp" "quantum_flux_analyzer" '{"energy_level": 3}' 15 50 "Quantum Flux Analyzer"

echo ""
echo "Phase 3: Heavy load on Neural Pattern Synthesizer"
generate_load "http://localhost/realserverfaketools/mcp" "neural_pattern_synthesizer" '{"input_patterns": ["alpha", "beta", "gamma"]}' 20 30 "Neural Pattern Synthesizer"

echo ""
echo "Phase 4: Mixed load - Temporal Anomaly Detector"
generate_load "http://localhost/realserverfaketools/mcp" "temporal_anomaly_detector" '{"timeframe": {"start": "2025-01-01", "end": "2025-12-31"}, "sensitivity": 5}' 12 75 "Temporal Anomaly Detector"

echo ""
echo "Phase 5: Synthetic Data Generation (variable complexity)"
for i in {1..8}; do
    record_count=$((5 + RANDOM % 20))
    ./keycloak/setup/generate-agent-token.sh agent-test-agent-m2m >/dev/null 2>&1
    source .oauth-tokens/agent-test-agent-m2m.env
    
    python cli/mcp_client.py --url "http://localhost/realserverfaketools/mcp" call --tool "synthetic_data_generator" --args "{\"schema\": {\"name\": \"string\", \"age\": \"integer\"}, \"record_count\": $record_count}" >/dev/null 2>&1 &
    sleep 0.1
done
wait
echo "✅ Synthetic Data Generation complete"

echo ""
echo "Phase 6: Gateway tools - list_services and healthcheck"
for i in {1..10}; do
    ./keycloak/setup/generate-agent-token.sh agent-test-agent-m2m >/dev/null 2>&1
    source .oauth-tokens/agent-test-agent-m2m.env
    
    if [ $((i % 2)) -eq 0 ]; then
        python cli/mcp_client.py --url "http://localhost/mcpgw/mcp" call --tool "list_services" --args '{}' >/dev/null 2>&1 &
    else
        python cli/mcp_client.py --url "http://localhost/mcpgw/mcp" call --tool "healthcheck" --args '{}' >/dev/null 2>&1 &
    fi
    sleep 0.05
done
wait
echo "✅ Gateway tools load complete"

echo ""
echo "=========================================="
echo "Load generation complete!"
echo "Check Grafana dashboard for metrics variation"
echo "=========================================="
