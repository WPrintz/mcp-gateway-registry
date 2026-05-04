"""
Lambda function to auto-register MCP servers, A2A agents, virtual servers,
and agent skills. Used as a CloudFormation Custom Resource.

Design notes
------------
Every mutation flows through `ensure()` which enforces per-step idempotency:
verify current state, mutate once if needed, then poll until verification
passes or the step's timeout expires. Failures are collected in
`failed_steps` and reported back to CloudFormation in the SUCCESS response
payload so the stack never rolls back (operators inspect FailedSteps).

Dev iteration loop (no CloudFormation deploy required):
    edit this file
    (cd cloudformation/aws-ecs/static && zip -qFS mcp_registration.zip mcp_registration.py cfnresponse.py)
    aws s3 cp .../mcp_registration.zip s3://<bucket>/<prefix>/static/mcp_registration.zip
    aws lambda update-function-code --function-name mcp-gateway-mcp-registration \
        --s3-bucket <bucket> --s3-key <prefix>/static/mcp_registration.zip
    aws lambda invoke --function-name mcp-gateway-mcp-registration \
        --payload file:///tmp/event.json /tmp/resp.json

Direct invocations (no ResponseURL in the event) skip the CFN callback and
return the registration summary as the Lambda response body -- use this
for fast iteration against a live deployment.
"""
import json
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request

import boto3
import cfnresponse

# ---------------------------------------------------------------------------
# Config tables (unchanged from prior inline implementation)
# ---------------------------------------------------------------------------

# MCP Servers to register enabled. /mcpgw/ (MCP Gateway Tools) is NOT here
# because it duplicates the built-in /airegistry-tools/ server which the
# registry auto-registers on startup.
MCP_SERVERS = [
    {
        'name': 'Current Time API',
        'description': 'A simple API that returns the current server time in various formats.',
        'path': '/currenttime/',
        'proxy_pass_url': 'http://currenttime-server:8000/',
        'tags': 'time,timezone,datetime,api,utility',
        'num_tools': '1',
        'is_python': 'true',
        'license': 'MIT-0',
    },
]

# Servers registered but left disabled -- workshop participants enable these.
DISABLED_SERVERS = [
    {
        'name': 'Real Server Fake Tools',
        'description': 'A collection of fake tools with interesting names for testing.',
        'path': '/realserverfaketools/',
        'proxy_pass_url': 'http://realserverfaketools-server:8002/',
        'tags': 'demo,fake,tools,testing',
        'num_tools': '6',
        'is_python': 'true',
        'license': 'MIT',
    },
]

# Virtual MCP servers aggregate tools from multiple backends.
VIRTUAL_SERVERS = [
    {
        'server_name': 'Dev Tools',
        'path': '/virtual/dev-tools',
        'description': 'A curated set of developer utilities combining time lookups and intelligent tool discovery from across the registry.',
        'tool_mappings': [
            {'tool_name': 'current_time_by_timezone', 'backend_server_path': '/currenttime/'},
            {'tool_name': 'intelligent_tool_finder', 'backend_server_path': '/airegistry-tools/'},
        ],
        'tags': ['developer', 'utility', 'curated'],
    },
]

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
    },
]

# A2A Agents. v1.0.20 added required field 'supportedProtocol'.
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
            {'id': 'manage_reservation', 'name': 'Manage Reservation', 'description': 'Update or cancel reservations.', 'tags': ['reservation', 'management']},
        ],
        'tags': ['travel', 'flight-booking', 'reservation'],
        'visibility': 'public',
        'license': 'MIT',
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
            {'id': 'create_trip_plan', 'name': 'Create Trip Plan', 'description': 'Create a trip planning record.', 'tags': ['planning']},
        ],
        'tags': ['travel', 'flight-search', 'trip-planning'],
        'visibility': 'public',
        'license': 'MIT',
    },
]

# ---------------------------------------------------------------------------
# Low-level HTTP helpers
# ---------------------------------------------------------------------------

_SSL_CTX = ssl.create_default_context()


def _log(msg):
    # Single entry point so we can prefix / redirect later if needed.
    print(msg, flush=True)


def _request(method, url, token, *, json_body=None, form_body=None, timeout=30):
    """Send a single authenticated request. Returns (http_status, body_dict_or_None).

    Never raises on HTTP error codes; raises only on transport/timeout errors.
    Caller decides what 4xx/5xx means for their step.
    """
    headers = {'Authorization': f'Bearer {token}'}
    data = None
    if json_body is not None:
        data = json.dumps(json_body).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    elif form_body is not None:
        data = urllib.parse.urlencode(form_body).encode('utf-8')
        headers['Content-Type'] = 'application/x-www-form-urlencoded'

    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, context=_SSL_CTX, timeout=timeout) as resp:
            raw = resp.read().decode('utf-8') if resp.length != 0 else ''
            try:
                return resp.status, (json.loads(raw) if raw else {})
            except json.JSONDecodeError:
                return resp.status, {'_raw': raw}
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8') if e.fp else ''
        try:
            body = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            body = {'_raw': raw}
        return e.code, body


def get_m2m_token(keycloak_url, client_id, client_secret):
    url = f"{keycloak_url}/realms/mcp-gateway/protocol/openid-connect/token"
    data = urllib.parse.urlencode({
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
    }).encode('utf-8')
    req = urllib.request.Request(url, data=data, method='POST')
    req.add_header('Content-Type', 'application/x-www-form-urlencoded')
    with urllib.request.urlopen(req, context=_SSL_CTX, timeout=30) as response:
        result = json.loads(response.read().decode('utf-8'))
        return result.get('access_token')


def wait_for_registry(registry_url, max_wait=60):
    start = time.time()
    while time.time() - start < max_wait:
        try:
            req = urllib.request.Request(f"{registry_url}/health", method='GET')
            with urllib.request.urlopen(req, context=_SSL_CTX, timeout=10) as response:
                if response.status == 200:
                    _log("  Registry is healthy")
                    return True
        except Exception:
            pass
        _log("  Waiting for registry...")
        time.sleep(5)
    raise Exception(f"Registry not healthy after {max_wait}s")


# ---------------------------------------------------------------------------
# Registry resource GETs used by verify_fn callables
# ---------------------------------------------------------------------------


def _get_server(registry_url, token, path):
    """Return server doc or None if 404."""
    status, body = _request('GET', f"{registry_url}/api/servers{path}", token)
    if status == 200:
        return body
    if status == 404:
        return None
    _log(f"    GET /api/servers{path} -> {status}: {body}")
    return None


def _get_agent(registry_url, token, path):
    status, body = _request('GET', f"{registry_url}/api/agents{path}", token)
    if status == 200:
        return body
    if status == 404:
        return None
    _log(f"    GET /api/agents{path} -> {status}: {body}")
    return None


def _get_virtual_server(registry_url, token, path):
    # path is "/virtual/dev-tools"; endpoint is /api/virtual-servers/virtual/dev-tools
    url_path = path.lstrip('/')
    status, body = _request('GET', f"{registry_url}/api/virtual-servers/{url_path}", token)
    if status == 200:
        return body
    if status == 404:
        return None
    _log(f"    GET /api/virtual-servers/{url_path} -> {status}: {body}")
    return None


def _get_skill(registry_url, token, name):
    status, body = _request('GET', f"{registry_url}/api/skills/{name}", token)
    if status == 200:
        return body
    if status == 404:
        return None
    _log(f"    GET /api/skills/{name} -> {status}: {body}")
    return None


# ---------------------------------------------------------------------------
# The ensure() helper
# ---------------------------------------------------------------------------


def ensure(step_name, verify_fn, mutate_fn=None, timeout_s=120, poll_s=5,
           failed_steps=None):
    """Idempotent step with verify-mutate-poll semantics.

    Returns True on success, False on timeout. Never raises -- exceptions
    inside verify_fn or mutate_fn are caught and converted to TIMEOUT.
    """
    start = time.time()
    _log(f"[{step_name}] STARTED")

    # Initial verify: maybe nothing to do.
    try:
        ok, detail = verify_fn()
    except Exception as e:
        ok, detail = False, f"verify_fn raised: {e!r}"

    if ok:
        _log(f"[{step_name}] SKIP ({detail})")
        return True

    # Mutate once.
    if mutate_fn is not None:
        try:
            mutate_fn()
        except Exception as e:
            _log(f"[{step_name}] mutate_fn raised: {e!r}")

    # Poll until verified or timeout.
    while time.time() - start < timeout_s:
        time.sleep(poll_s)
        try:
            ok, detail = verify_fn()
        except Exception as e:
            ok, detail = False, f"verify_fn raised: {e!r}"
        if ok:
            elapsed = int(time.time() - start)
            _log(f"[{step_name}] DONE in {elapsed}s ({detail})")
            return True

    elapsed = int(time.time() - start)
    reason = detail or "verify_fn never returned True"
    _log(f"[{step_name}] TIMEOUT after {elapsed}s (reason: {reason})")
    if failed_steps is not None:
        failed_steps.append({
            'step': step_name,
            'reason': reason,
            'elapsed_s': elapsed,
        })
    return False


# ---------------------------------------------------------------------------
# Step implementations (verify + mutate pairs)
# ---------------------------------------------------------------------------


def step_register_server(registry_url, token, server, failed_steps):
    path = server['path']

    def verify():
        doc = _get_server(registry_url, token, path)
        if doc is None:
            return False, "server not found"
        return True, f"server present ({doc.get('server_name')})"

    def mutate():
        status, body = _request(
            'POST', f"{registry_url}/api/servers/register", token, form_body=server, timeout=60,
        )
        _log(f"    POST /api/servers/register -> {status}")
        if status not in (200, 201, 409):
            _log(f"    body: {body}")

    return ensure(
        f"register_server:{server['name']}",
        verify, mutate,
        timeout_s=60, poll_s=3, failed_steps=failed_steps,
    )


def step_set_enabled(registry_url, token, path, desired, failed_steps,
                     timeout_s=60):
    """Set server's enabled state to `desired` (bool)."""

    def verify():
        doc = _get_server(registry_url, token, path)
        if doc is None:
            return False, "server not found (cannot toggle)"
        current = bool(doc.get('is_enabled'))
        if current == desired:
            return True, f"is_enabled={current}"
        return False, f"is_enabled={current}, want {desired}"

    def mutate():
        status, body = _request(
            'POST', f"{registry_url}/api/servers/toggle", token,
            form_body={'path': path, 'new_state': 'true' if desired else 'false'},
            timeout=120,
        )
        _log(f"    POST /api/servers/toggle path={path} new_state={desired} -> {status}")
        if status >= 400:
            _log(f"    body: {body}")

    label = 'enable' if desired else 'disable'
    return ensure(
        f"{label}_server:{path}",
        verify, mutate,
        timeout_s=timeout_s, poll_s=3, failed_steps=failed_steps,
    )


def step_wait_tool_list(registry_url, token, path, failed_steps, timeout_s=300):
    """Wait until server doc has tool_list populated. If it stays empty past
    60s, re-toggle OFF->ON to force a fresh health check cycle.
    """
    start = time.time()
    retoggle_done = False

    def verify():
        doc = _get_server(registry_url, token, path)
        if doc is None:
            return False, "server not found"
        tool_list = doc.get('tool_list') or []
        if len(tool_list) > 0:
            names = [t.get('name') for t in tool_list if isinstance(t, dict)]
            return True, f"{len(tool_list)} tools: {names}"
        return False, f"tool_list empty (num_tools={doc.get('num_tools')})"

    def mutate():
        # Initial mutate is a no-op; the preceding enable step already
        # triggered an immediate health check. We rely on polling.
        pass

    # First attempt: wait up to 60s with the initial enable as the trigger.
    first_budget = min(60, timeout_s)
    ok = ensure(
        f"wait_tool_list:{path}",
        verify, mutate,
        timeout_s=first_budget, poll_s=5, failed_steps=None,  # don't record yet
    )
    if ok:
        return True

    # Recovery: toggle OFF then ON, then wait out the remaining budget.
    remaining = timeout_s - (time.time() - start)
    if remaining <= 0:
        failed_steps.append({
            'step': f"wait_tool_list:{path}",
            'reason': "tool_list empty after initial 60s wait",
            'elapsed_s': int(time.time() - start),
        })
        return False

    _log(f"[wait_tool_list:{path}] RECOVERY: toggling OFF then ON to force health re-check")
    retoggle_done = True
    _request('POST', f"{registry_url}/api/servers/toggle", token,
             form_body={'path': path, 'new_state': 'false'}, timeout=30)
    time.sleep(3)
    _request('POST', f"{registry_url}/api/servers/toggle", token,
             form_body={'path': path, 'new_state': 'true'}, timeout=120)

    return ensure(
        f"wait_tool_list:{path}:after-retoggle",
        verify, mutate_fn=None,
        timeout_s=int(remaining), poll_s=10, failed_steps=failed_steps,
    )


def step_register_agent(registry_url, token, agent, failed_steps):
    path = agent['path']

    def verify():
        doc = _get_agent(registry_url, token, path)
        if doc is None:
            return False, "agent not found"
        return True, f"agent present ({doc.get('name', path)})"

    def mutate():
        status, body = _request(
            'POST', f"{registry_url}/api/agents/register", token, json_body=agent, timeout=60,
        )
        _log(f"    POST /api/agents/register -> {status}")
        if status not in (200, 201, 409):
            _log(f"    body: {body}")

    return ensure(
        f"register_agent:{agent['name']}",
        verify, mutate,
        timeout_s=60, poll_s=3, failed_steps=failed_steps,
    )


def step_register_virtual_server(registry_url, token, vs, failed_steps):
    path = vs['path']

    def verify():
        doc = _get_virtual_server(registry_url, token, path)
        if doc is None:
            return False, "virtual server not found"
        return True, f"virtual server present ({doc.get('server_name')})"

    def mutate():
        status, body = _request(
            'POST', f"{registry_url}/api/virtual-servers", token, json_body=vs, timeout=60,
        )
        _log(f"    POST /api/virtual-servers -> {status}")
        if status not in (200, 201, 409):
            _log(f"    body: {body}")

    return ensure(
        f"register_virtual_server:{vs['server_name']}",
        verify, mutate,
        timeout_s=120, poll_s=5, failed_steps=failed_steps,
    )


def step_enable_virtual_server(registry_url, token, path, failed_steps):

    def verify():
        doc = _get_virtual_server(registry_url, token, path)
        if doc is None:
            return False, "virtual server not found"
        if doc.get('is_enabled') is True:
            return True, "is_enabled=True"
        return False, f"is_enabled={doc.get('is_enabled')}"

    def mutate():
        vs_path = path.lstrip('/')
        status, body = _request(
            'POST', f"{registry_url}/api/virtual-servers/{vs_path}/toggle", token,
            json_body={'enabled': True}, timeout=30,
        )
        _log(f"    POST /api/virtual-servers/{vs_path}/toggle -> {status}")
        if status >= 400:
            _log(f"    body: {body}")

    return ensure(
        f"enable_virtual_server:{path}",
        verify, mutate,
        timeout_s=60, poll_s=3, failed_steps=failed_steps,
    )


def step_register_skill(registry_url, token, skill, failed_steps):
    name = skill['name']

    def verify():
        doc = _get_skill(registry_url, token, name)
        if doc is None:
            return False, "skill not found"
        return True, f"skill present ({doc.get('name', name)})"

    def mutate():
        status, body = _request(
            'POST', f"{registry_url}/api/skills", token, json_body=skill, timeout=30,
        )
        _log(f"    POST /api/skills -> {status}")
        if status not in (200, 201, 409):
            _log(f"    body: {body}")

    return ensure(
        f"register_skill:{name}",
        verify, mutate,
        timeout_s=60, poll_s=3, failed_steps=failed_steps,
    )


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------


INTER_STEP_SLEEP_S = 3


def run_registration(event):
    """Run all registration steps; return the summary Data payload."""
    properties = event.get('ResourceProperties', {})
    registry_url = properties.get('RegistryUrl')
    keycloak_url = properties.get('KeycloakUrl')
    m2m_secret_arn = properties.get('M2MClientSecretArn')

    failed_steps = []
    servers_registered = 0
    agents_registered = 0
    virtual_servers_registered = 0
    skills_registered = 0

    # --- 1. M2M token -------------------------------------------------------
    secrets = boto3.client('secretsmanager')
    m2m_secret = json.loads(
        secrets.get_secret_value(SecretId=m2m_secret_arn)['SecretString']
    )
    client_id = m2m_secret.get('client_id', 'mcp-gateway-m2m')
    client_secret = m2m_secret.get('client_secret')

    _log(f"Getting M2M token from {keycloak_url}")
    token = get_m2m_token(keycloak_url, client_id, client_secret)
    if not token:
        raise Exception("Failed to get M2M token")

    # --- 2. Registry health -------------------------------------------------
    _log("Waiting for registry to be healthy...")
    wait_for_registry(registry_url)
    _log("Warm-up delay (10s)...")
    time.sleep(10)

    # --- 3. Enabled MCP servers (register -> enable -> wait tool_list) ------
    _log("=== Enabled MCP servers ===")
    for server in MCP_SERVERS:
        if step_register_server(registry_url, token, server, failed_steps):
            servers_registered += 1
        time.sleep(INTER_STEP_SLEEP_S)
        step_set_enabled(registry_url, token, server['path'], True, failed_steps)
        time.sleep(INTER_STEP_SLEEP_S)
        step_wait_tool_list(registry_url, token, server['path'], failed_steps)
        time.sleep(INTER_STEP_SLEEP_S)

    # --- 4. Disabled MCP servers (register -> disable) ----------------------
    _log("=== Disabled MCP servers ===")
    for server in DISABLED_SERVERS:
        step_register_server(registry_url, token, server, failed_steps)
        time.sleep(INTER_STEP_SLEEP_S)
        step_set_enabled(registry_url, token, server['path'], False, failed_steps)
        time.sleep(INTER_STEP_SLEEP_S)

    # --- 5. A2A Agents ------------------------------------------------------
    # Agent enable is skipped (upstream issue #891 blocks M2M toggle).
    _log("=== A2A agents ===")
    for agent in A2A_AGENTS:
        if step_register_agent(registry_url, token, agent, failed_steps):
            agents_registered += 1
        time.sleep(INTER_STEP_SLEEP_S)
    _log("Skipping agent enable (upstream issue #891 workaround)")

    # --- 6. Virtual servers -------------------------------------------------
    # Also needs a tool_list for airegistry-tools, which the registry
    # auto-registers and auto-discovers -- poll to be sure before POST.
    _log("=== Virtual servers ===")
    for vs in VIRTUAL_SERVERS:
        # Make sure every referenced backend has a populated tool_list.
        backends = sorted({m['backend_server_path'] for m in vs.get('tool_mappings', [])})
        for backend in backends:
            # Only wait; these should already be populated by earlier steps
            # (for MCP_SERVERS) or by registry auto-registration (for
            # /airegistry-tools/). 120s is plenty if they already are.
            step_wait_tool_list(registry_url, token, backend, failed_steps, timeout_s=120)
            time.sleep(INTER_STEP_SLEEP_S)

        if step_register_virtual_server(registry_url, token, vs, failed_steps):
            virtual_servers_registered += 1
            time.sleep(INTER_STEP_SLEEP_S)
            step_enable_virtual_server(registry_url, token, vs['path'], failed_steps)
        time.sleep(INTER_STEP_SLEEP_S)

    # --- 7. Agent skills ----------------------------------------------------
    _log("=== Agent skills ===")
    for skill in AGENT_SKILLS:
        if step_register_skill(registry_url, token, skill, failed_steps):
            skills_registered += 1
        time.sleep(INTER_STEP_SLEEP_S)

    # --- 8. Summary ---------------------------------------------------------
    overall = 'OK' if not failed_steps else 'PARTIAL'
    _log(f"Registration {overall}: {servers_registered} servers, "
         f"{agents_registered} agents, "
         f"{virtual_servers_registered} virtual servers, "
         f"{skills_registered} skills, "
         f"{len(failed_steps)} failed steps")
    if failed_steps:
        _log("Failed steps:")
        for fs in failed_steps:
            _log(f"  - {fs['step']}: {fs['reason']} ({fs['elapsed_s']}s)")

    return {
        'ServersRegistered': servers_registered,
        'AgentsRegistered': agents_registered,
        'VirtualServersRegistered': virtual_servers_registered,
        'SkillsRegistered': skills_registered,
        'FailedSteps': failed_steps,
        'OverallStatus': overall,
    }


def handler(event, context):
    """Lambda entry point.

    - CloudFormation Custom Resource events (ResponseURL present) always
      return SUCCESS to CFN so the stack does not roll back. Failures are
      reported in Data.FailedSteps / Data.OverallStatus.
    - Direct invocations (no ResponseURL) return the summary as the Lambda
      response body for fast iteration via `aws lambda invoke`.
    """
    _log(f"Event: {json.dumps(event)}")
    is_cfn = 'ResponseURL' in event
    request_type = event.get('RequestType')

    if is_cfn and request_type == 'Delete':
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {})
        return {'OverallStatus': 'OK', 'Note': 'Delete no-op'}

    try:
        data = run_registration(event)
    except Exception as e:
        import traceback
        traceback.print_exc()
        data = {
            'ServersRegistered': 0,
            'AgentsRegistered': 0,
            'VirtualServersRegistered': 0,
            'SkillsRegistered': 0,
            'FailedSteps': [{'step': 'orchestration', 'reason': f"{type(e).__name__}: {e}", 'elapsed_s': 0}],
            'OverallStatus': 'PARTIAL',
        }

    if is_cfn:
        # Always SUCCESS to CFN -- FailedSteps in Data is the signal.
        cfnresponse.send(event, context, cfnresponse.SUCCESS, data)
    return data
