"""
Lambda function to auto-register MCP servers, A2A agents, virtual
servers, and agent skills. Used as a CloudFormation Custom Resource.
Runs after ServiceNetworkHealthCheck confirms Service Connect works.
"""
import json
import urllib.request
import urllib.parse
import urllib.error
import ssl
import boto3
import cfnresponse
import time

# MCP Servers to register (form data fields for /api/servers/register)
# Note: /mcpgw/ (MCP Gateway Tools) is NOT registered here because
# it is redundant with the built-in /airegistry-tools/ server which
# is auto-registered on startup and points to the same backend.
MCP_SERVERS = [
    {
        'name': 'Current Time API',
        'description': 'A simple API that returns the current server time in various formats.',
        'path': '/currenttime/',
        'proxy_pass_url': 'http://currenttime-server:8000/',
        'tags': 'time,timezone,datetime,api,utility',
        'num_tools': '1',
        'is_python': 'true',
        'license': 'MIT-0'
    },
]

# Servers to register but leave disabled (workshop participants enable these)
DISABLED_SERVERS = [
    {
        'name': 'Real Server Fake Tools',
        'description': 'A collection of fake tools with interesting names for testing.',
        'path': '/realserverfaketools/',
        'proxy_pass_url': 'http://realserverfaketools-server:8002/',
        'tags': 'demo,fake,tools,testing',
        'num_tools': '6',
        'is_python': 'true',
        'license': 'MIT'
    }
]

# Virtual MCP Servers to register (aggregates tools from multiple backends)
VIRTUAL_SERVERS = [
    {
        'server_name': 'Dev Tools',
        'path': '/virtual/dev-tools',
        'description': 'A curated set of developer utilities combining time lookups and intelligent tool discovery from across the registry.',
        'tool_mappings': [
            {
                'tool_name': 'current_time_by_timezone',
                'backend_server_path': '/currenttime/',
            },
            {
                'tool_name': 'intelligent_tool_finder',
                'backend_server_path': '/airegistry-tools/',
            },
        ],
        'tags': ['developer', 'utility', 'curated'],
    }
]

# Agent Skills to register (SKILL.md-based capabilities)
AGENT_SKILLS = [
    {
        'name': 'frontend-design',
        'description': 'Create distinctive, production-grade frontend interfaces with high design quality.',
        'skill_md_url': 'https://raw.githubusercontent.com/anthropics/skills/refs/heads/main/skills/frontend-design/SKILL.md',
        'tags': ['design', 'frontend', 'ui'],
    },
    {
        'name': 'canvas-design',
        'description': 'Create beautiful visual art in .png and .pdf documents using design philosophy.',
        'skill_md_url': 'https://raw.githubusercontent.com/anthropics/skills/refs/heads/main/skills/canvas-design/SKILL.md',
        'tags': ['design', 'canvas', 'art'],
    }
]

# A2A Agents to register
# v1.0.20 added required field 'supportedProtocol' (values: 'a2a' | 'other').
# Both workshop agents speak A2A protocol.
A2A_AGENTS = [
    {
        'name': 'Flight Booking Agent',
        'description': 'Flight booking and reservation management agent',
        'url': 'http://flight-booking-agent:9000/',
        'path': '/flight-booking-agent',
        'supportedProtocol': 'a2a',
        'protocolVersion': '0.3.0',
        'version': '0.0.1',
        'capabilities': {'streaming': True},
        'defaultInputModes': ['text/plain', 'application/json'],
        'defaultOutputModes': ['text/plain', 'application/json'],
        'provider': {'organization': 'MCP Gateway Workshop', 'url': 'https://example.com'},
        'skills': [
            {'id': 'check_availability', 'name': 'Check Availability', 'description': 'Check seat availability for a flight.', 'tags': ['flight', 'availability']},
            {'id': 'reserve_flight', 'name': 'Reserve Flight', 'description': 'Reserve seats on a flight.', 'tags': ['flight', 'reservation']},
            {'id': 'confirm_booking', 'name': 'Confirm Booking', 'description': 'Confirm and finalize a booking.', 'tags': ['flight', 'confirmation']},
            {'id': 'process_payment', 'name': 'Process Payment', 'description': 'Process payment (simulated).', 'tags': ['payment']},
            {'id': 'manage_reservation', 'name': 'Manage Reservation', 'description': 'Update or cancel reservations.', 'tags': ['reservation', 'management']}
        ],
        'tags': ['travel', 'flight-booking', 'reservation'],
        'visibility': 'public',
        'license': 'MIT'
    },
    {
        'name': 'Travel Assistant Agent',
        'description': 'Flight search and trip planning agent',
        'url': 'http://travel-assistant-agent:9000/',
        'path': '/travel-assistant-agent',
        'supportedProtocol': 'a2a',
        'protocolVersion': '0.3.0',
        'version': '0.0.1',
        'capabilities': {'streaming': True},
        'defaultInputModes': ['text'],
        'defaultOutputModes': ['text'],
        'provider': {'organization': 'MCP Gateway Workshop', 'url': 'https://example.com'},
        'skills': [
            {'id': 'search_flights', 'name': 'Search Flights', 'description': 'Search for available flights.', 'tags': ['flight', 'search']},
            {'id': 'check_prices', 'name': 'Check Prices', 'description': 'Get pricing and availability.', 'tags': ['pricing']},
            {'id': 'get_recommendations', 'name': 'Get Recommendations', 'description': 'Get flight recommendations.', 'tags': ['recommendations']},
            {'id': 'create_trip_plan', 'name': 'Create Trip Plan', 'description': 'Create a trip planning record.', 'tags': ['planning']}
        ],
        'tags': ['travel', 'flight-search', 'trip-planning'],
        'visibility': 'public',
        'license': 'MIT'
    }
]

def get_m2m_token(keycloak_url, client_id, client_secret):
    """Get M2M access token from Keycloak."""
    url = f"{keycloak_url}/realms/mcp-gateway/protocol/openid-connect/token"
    data = urllib.parse.urlencode({
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret
    }).encode('utf-8')
    req = urllib.request.Request(url, data=data, method='POST')
    req.add_header('Content-Type', 'application/x-www-form-urlencoded')
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
        result = json.loads(response.read().decode('utf-8'))
        return result.get('access_token')

def wait_for_registry(registry_url, max_wait=60):
    """Wait for the registry to be healthy."""
    start = time.time()
    while time.time() - start < max_wait:
        try:
            req = urllib.request.Request(f"{registry_url}/health", method='GET')
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, context=ctx, timeout=10) as response:
                if response.status == 200:
                    print("  Registry is healthy")
                    return True
        except Exception:
            pass
        print("  Waiting for registry...")
        time.sleep(5)
    raise Exception(f"Registry not healthy after {max_wait}s")

def api_request_form(url, token, form_data, max_retries=5):
    """Make authenticated POST request with form data to Registry API."""
    encoded_data = urllib.parse.urlencode(form_data).encode('utf-8')
    ctx = ssl.create_default_context()
    last_error = None

    for attempt in range(max_retries):
        req = urllib.request.Request(url, data=encoded_data, method='POST')
        req.add_header('Authorization', f'Bearer {token}')
        req.add_header('Content-Type', 'application/x-www-form-urlencoded')
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=60) as response:
                if response.status in [200, 201, 204]:
                    try:
                        return json.loads(response.read().decode('utf-8'))
                    except:
                        return {'success': True}
                return {'success': True}
        except urllib.error.HTTPError as e:
            if e.code == 409:
                return {'exists': True, 'success': False}
            if e.code in [400, 404, 422]:
                body = e.read().decode('utf-8')
                if 'already' in body.lower() or 'exists' in body.lower():
                    return {'exists': True, 'success': False}
                print(f"API error {e.code}: {body}")
                return {'success': False, 'error': body}
            if e.code in [500, 502, 503, 504]:
                last_error = e
                wait_time = 2 ** attempt
                print(f"    Transient error {e.code}, retry {attempt + 1}/{max_retries} in {wait_time}s...")
                time.sleep(wait_time)
                continue
            raise
        except (urllib.error.URLError, TimeoutError) as e:
            last_error = e
            wait_time = 2 ** attempt
            print(f"    Connection error, retry {attempt + 1}/{max_retries} in {wait_time}s: {str(e)}")
            time.sleep(wait_time)
            continue

    if last_error:
        raise last_error
    raise Exception(f"Request failed after {max_retries} attempts")

def delete_server(registry_url, token, server_path):
    """Delete a server from the registry by path."""
    url = f"{registry_url}/api/servers/remove"
    data = urllib.parse.urlencode({'path': server_path}).encode('utf-8')
    req = urllib.request.Request(url, data=data, method='POST')
    req.add_header('Authorization', f'Bearer {token}')
    req.add_header('Content-Type', 'application/x-www-form-urlencoded')
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
            print(f"    Deleted existing server: {server_path}")
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return True
        print(f"    Delete failed ({e.code}): {e.read().decode('utf-8')}")
        return False
    except Exception as e:
        print(f"    Delete error: {str(e)}")
        return False

def delete_virtual_server(registry_url, token, vs_path):
    """Delete a virtual server from the registry by path."""
    url = f"{registry_url}/api/virtual-servers/{vs_path.lstrip('/')}"
    req = urllib.request.Request(url, method='DELETE')
    req.add_header('Authorization', f'Bearer {token}')
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
            print(f"    Deleted existing virtual server: {vs_path}")
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return True
        print(f"    Delete failed ({e.code}): {e.read().decode('utf-8')}")
        return False
    except Exception as e:
        print(f"    Delete error: {str(e)}")
        return False

def delete_agent(registry_url, token, agent_path):
    """Delete an agent from the registry by path."""
    url = f"{registry_url}/api/agents/{agent_path.lstrip('/')}"
    req = urllib.request.Request(url, method='DELETE')
    req.add_header('Authorization', f'Bearer {token}')
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
            print(f"    Deleted existing agent: {agent_path}")
            return True
    except urllib.error.HTTPError as e:
        if e.code in [404, 204]:
            return True
        print(f"    Delete failed ({e.code}): {e.read().decode('utf-8')}")
        return False
    except Exception as e:
        print(f"    Delete error: {str(e)}")
        return False

def delete_skill(registry_url, token, skill_path):
    """Delete a skill from the registry by path."""
    url = f"{registry_url}/api/skills/{skill_path.lstrip('/')}"
    req = urllib.request.Request(url, method='DELETE')
    req.add_header('Authorization', f'Bearer {token}')
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=30) as response:
            print(f"    Deleted existing skill: {skill_path}")
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return True
        print(f"    Delete failed ({e.code}): {e.read().decode('utf-8')}")
        return False
    except Exception as e:
        print(f"    Delete error: {str(e)}")
        return False

def api_request_json(url, token, json_data, max_retries=5):
    """Make authenticated POST request with JSON data to Registry API."""
    ctx = ssl.create_default_context()
    data = json.dumps(json_data).encode('utf-8')
    last_error = None

    for attempt in range(max_retries):
        req = urllib.request.Request(url, method='POST')
        req.add_header('Authorization', f'Bearer {token}')
        req.add_header('Content-Type', 'application/json')
        req.data = data
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=60) as response:
                if response.status in [200, 201, 204]:
                    try:
                        return json.loads(response.read().decode('utf-8'))
                    except:
                        return {'success': True}
                return {'success': True}
        except urllib.error.HTTPError as e:
            if e.code == 409:
                return {'exists': True, 'success': False}
            if e.code in [400, 404, 422]:
                body = e.read().decode('utf-8')
                if 'already' in body.lower() or 'exists' in body.lower():
                    return {'exists': True, 'success': False}
                print(f"API error {e.code}: {body}")
                return {'success': False, 'error': body}
            if e.code in [500, 502, 503, 504]:
                last_error = e
                wait_time = 2 ** attempt
                print(f"    Transient error {e.code}, retry {attempt + 1}/{max_retries} in {wait_time}s...")
                time.sleep(wait_time)
                continue
            raise
        except (urllib.error.URLError, TimeoutError) as e:
            last_error = e
            wait_time = 2 ** attempt
            print(f"    Connection error, retry {attempt + 1}/{max_retries} in {wait_time}s: {str(e)}")
            time.sleep(wait_time)
            continue

    if last_error:
        raise last_error
    raise Exception(f"Request failed after {max_retries} attempts")

def handler(event, context):
    """CloudFormation Custom Resource handler."""
    print(f"Event: {json.dumps(event)}")
    request_type = event.get('RequestType')
    properties = event.get('ResourceProperties', {})
    registry_url = properties.get('RegistryUrl')
    keycloak_url = properties.get('KeycloakUrl')
    m2m_secret_arn = properties.get('M2MClientSecretArn')

    if request_type == 'Delete':
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
        return

    try:
        # Step 1: Get M2M token
        secrets = boto3.client('secretsmanager')
        m2m_secret = json.loads(
            secrets.get_secret_value(SecretId=m2m_secret_arn)['SecretString']
        )
        client_id = m2m_secret.get('client_id', 'mcp-gateway-m2m')
        client_secret = m2m_secret.get('client_secret')

        print(f"Getting M2M token from {keycloak_url}")
        token = get_m2m_token(keycloak_url, client_id, client_secret)
        if not token:
            raise Exception("Failed to get M2M token")
        print("Got M2M token")

        # Step 2: Wait for registry health
        print("Waiting for registry to be healthy...")
        wait_for_registry(registry_url)

        # Step 3: Warm-up delay
        print("Warm-up delay (10s)...")
        time.sleep(10)

        # Step 4: Register MCP Servers (form data, delete-then-create upsert)
        print("Registering MCP Servers...")
        servers_registered = 0
        for server in MCP_SERVERS:
            server_data = server.copy()
            print(f"  Registering: {server_data['name']}")
            delete_server(registry_url, token, server_data['path'])
            result = api_request_form(
                f"{registry_url}/api/servers/register",
                token,
                server_data
            )
            # exists = our timed-out attempt already succeeded (we deleted first)
            if result.get('success') or result.get('path') or result.get('exists'):
                print(f"    OK")
                servers_registered += 1
            else:
                print(f"    Failed: {result}")
            # Toggle ON — newly registered servers default to disabled
            print(f"    Toggling ON: {server_data['path']}")
            try:
                toggle_data = urllib.parse.urlencode({
                    'path': server_data['path'],
                    'new_state': 'true'
                }).encode('utf-8')
                req = urllib.request.Request(
                    f"{registry_url}/api/servers/toggle",
                    data=toggle_data, method='POST'
                )
                req.add_header('Authorization', f'Bearer {token}')
                req.add_header('Content-Type', 'application/x-www-form-urlencoded')
                ctx = ssl.create_default_context()
                with urllib.request.urlopen(req, context=ctx, timeout=120) as resp:
                    result = json.loads(resp.read().decode('utf-8'))
                    print(f"    Toggled ON: status={result.get('status')}, tools={result.get('num_tools')}")
            except Exception as e:
                print(f"    Toggle ON failed: {e}")

        # Step 5: Register disabled servers + toggle OFF
        print("Registering disabled servers...")
        for server in DISABLED_SERVERS:
            server_data = server.copy()
            print(f"  Registering (disabled): {server_data['name']}")
            delete_server(registry_url, token, server_data['path'])
            result = api_request_form(
                f"{registry_url}/api/servers/register",
                token,
                server_data
            )
            if result.get('success') or result.get('path') or result.get('exists'):
                print(f"    OK (created)")
            else:
                print(f"    Failed: {result}")
            # Toggle OFF — workshop participants enable these manually
            print(f"    Toggling OFF: {server_data['path']}")
            try:
                toggle_data = urllib.parse.urlencode({
                    'path': server_data['path'],
                    'new_state': 'false'
                }).encode('utf-8')
                req = urllib.request.Request(
                    f"{registry_url}/api/servers/toggle",
                    data=toggle_data, method='POST'
                )
                req.add_header('Authorization', f'Bearer {token}')
                req.add_header('Content-Type', 'application/x-www-form-urlencoded')
                ctx = ssl.create_default_context()
                with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
                    print(f"    Toggled OFF")
            except Exception as e:
                print(f"    Toggle OFF failed: {e}")

        # Step 6: Register all A2A Agents first, then enable them
        print("Registering A2A Agents...")
        agents_registered = 0
        registered_agent_paths = []
        for agent in A2A_AGENTS:
            agent_data = agent.copy()
            print(f"  Registering: {agent_data['name']}")
            delete_agent(registry_url, token, agent_data['path'])
            result = api_request_json(
                f"{registry_url}/api/agents/register",
                token,
                agent_data
            )
            # exists = our timed-out attempt already succeeded (we deleted first)
            if result.get('success') or result.get('agent') or result.get('path') or result.get('exists'):
                print(f"    OK")
                agents_registered += 1
                registered_agent_paths.append(agent_data['path'])
            else:
                print(f"    Failed: {result}")

        # Enable agents after all are registered (avoids state
        # persistence races between register → enable → delete cycles)
        #
        # DISABLED: upstream CSRF bug blocks M2M Bearer-token clients
        # from calling POST /api/agents/{path}/toggle. Issue filed:
        # https://github.com/agentic-community/mcp-gateway-registry/issues/891
        # Restore this block once #891 is merged upstream.
        # Until then, workshop operator must manually enable agents
        # via the Discover UI once per deployed account.
        #
        # print("Enabling registered agents...")
        # for agent_path in registered_agent_paths:
        #     try:
        #         url = f"{registry_url}/api/agents{agent_path}/toggle?enabled=true"
        #         req = urllib.request.Request(url, data=b'', method='POST')
        #         req.add_header('Authorization', f'Bearer {token}')
        #         ctx = ssl.create_default_context()
        #         with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
        #             result = json.loads(resp.read().decode('utf-8'))
        #             if result.get('is_enabled'):
        #                 print(f"    Enabled {agent_path}")
        #             else:
        #                 print(f"    Enable response for {agent_path}: {result}")
        #     except Exception as e:
        #         print(f"    Enable failed for {agent_path}: {e}")
        print("Skipping agent enable (upstream issue #891 workaround)")

        # Step 7: Register Virtual Servers (JSON, retry loop for tool discovery)
        print("Registering Virtual MCP Servers...")
        virtual_servers_registered = 0
        for vs in VIRTUAL_SERVERS:
            vs_data = vs.copy()
            print(f"  Registering: {vs_data['server_name']}")
            delete_virtual_server(registry_url, token, vs_data['path'])
            vs_created = False
            for vs_attempt in range(6):
                result = api_request_json(
                    f"{registry_url}/api/virtual-servers",
                    token,
                    vs_data
                )
                if result.get('success') or result.get('path') or result.get('exists'):
                    print(f"    OK")
                    vs_created = True
                    virtual_servers_registered += 1
                    break
                else:
                    error_str = str(result.get('error', ''))
                    if 'not found' in error_str.lower() and 'available tools' in error_str.lower():
                        wait = 10 * (vs_attempt + 1)
                        print(f"    Tool discovery incomplete, retry {vs_attempt + 1}/6 in {wait}s...")
                        time.sleep(wait)
                        continue
                    print(f"    Failed: {result}")
                    break

            if vs_created:
                vs_path = vs_data['path'].lstrip('/')
                print(f"    Enabling virtual server: {vs_data['path']}")
                try:
                    toggle_result = api_request_json(
                        f"{registry_url}/api/virtual-servers/{vs_path}/toggle",
                        token,
                        {'enabled': True}
                    )
                    if toggle_result.get('is_enabled') is True or toggle_result.get('path'):
                        print(f"    Enabled")
                    else:
                        print(f"    Enable failed: {toggle_result}")
                except Exception as toggle_err:
                    print(f"    Enable error (non-fatal): {toggle_err}")

        # Step 8: Register Skills (JSON, non-fatal, max_retries=2)
        print("Registering Agent Skills...")
        skills_registered = 0
        for skill in AGENT_SKILLS:
            skill_data = skill.copy()
            skill_name = skill_data['name']
            print(f"  Registering: {skill_name}")
            try:
                delete_skill(registry_url, token, skill_name)
                result = api_request_json(
                    f"{registry_url}/api/skills",
                    token,
                    skill_data,
                    max_retries=2
                )
                if result.get('path') or result.get('exists'):
                    print(f"    OK")
                    skills_registered += 1
                else:
                    print(f"    Failed: {result}")
                    continue
            except Exception as reg_err:
                print(f"    Registration error (non-fatal): {reg_err}")
                continue

            # v1.0.20: Skills register with is_enabled=True by default
            # (skill_service.py:532). The /toggle endpoint additionally
            # enforces CSRF validation (csrf.py:verify_csrf_token_flexible),
            # which requires a browser session cookie -- M2M Bearer tokens
            # cannot satisfy it. Skip the toggle call since it is both
            # unnecessary and always 403s for M2M clients.

        # Step 9: Report results
        print(f"Registration complete: {servers_registered} servers, {agents_registered} agents, {virtual_servers_registered} virtual servers, {skills_registered} skills")
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {
            'ServersRegistered': servers_registered,
            'AgentsRegistered': agents_registered,
            'VirtualServersRegistered': virtual_servers_registered,
            'SkillsRegistered': skills_registered
        })

    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        cfnresponse.send(event, context, cfnresponse.FAILED, {
            'Error': str(e)
        })
