# CloudFormation Workshop Porting Reference

*Created: 2026-02-25*
*Source branch: v1.0.15 (off updated main)*
*Previous work: feature/cloudformation-v1.0.12-prebuilt-containers (archived)*

---

## Universal Lessons (Carry Forward)

These apply to all CloudFormation workshop development:

1. **Subshell pattern for AWS creds** - Always `(source .scratchpad/ws-creds.env; aws ...)` - never `--profile`
2. **Never `git add -A` or `git commit --no-verify`** - Only stage specific files; pre-commit hooks exist for security scanning
3. **IaC principle** - All infrastructure changes via CloudFormation, not direct API calls (direct API OK for debugging only)
4. **Validate shell scripts with `bash -n`** before running
5. **CloudFormation inline buildspecs need stack update to change** - Can't hot-patch CodeBuild; must update template and redeploy
6. **Service Connect DNS only works within container network namespace** - Python/Go processes can't resolve Service Connect names; only Envoy sidecar proxy handles resolution
7. **IPv6 Service Connect: 3 failure modes and entrypoint fixes** (PR #548 merged)
   - Lua cosocket DNS failure: `getent ahostsv4` in entrypoint rewrites to IPv4 literal
   - Python health checker FQDN mismatch: inject FQDN aliases into `/etc/hosts`
   - nginx auth proxy_pass: resolves via Envoy, self-heals on reload
8. **Health gate DNS issue** (Issue #496 still open) - unhealthy servers get commented-out nginx location blocks
9. **ADOT sidecar pattern** - Co-locate ADOT as sidecar in metrics-service task, scrape `localhost:9465`
10. **`rate()` vs `increase()`** for sparse high-cardinality Prometheus counters - `increase()` works with single data points, `rate()` needs 2+
11. **HTTP headers cannot contain raw newlines** - `capture_body.lua` must sanitize `\r\n` before setting X-Body header
12. **Never use `log`/`echo` inside functions captured via `$()`** - Output gets captured into the variable instead of displaying
13. **`aws s3 sync --delete` to shared prefix deletes all sub-prefixes** - Never use `--delete` when syncing to a shared prefix
14. **WSS regional bucket names are non-predictable** - Use CloudFormation Mappings table, not hardcoded URLs
15. **OTel histogram bucket defaults unusable for sub-second latencies** - Configure explicit boundaries from 5ms-300s
16. **MCP Streamable HTTP is stateful** - Session ID from initialize must be forwarded to subsequent calls
17. **In nginx, `os.getenv()` in Lua only works for variables declared with `env VAR;` at main context**
18. **`ngx.ctx` is the reliable way to pass data between Lua phases** when `auth_request` subrequests are involved
19. **CodeBuild compute type provisioning time dominates for short builds** - Right-size compute to workload
20. **Workshop Studio S3 has per-object size limit (1GB)** - Split large artifacts into 512MB parts
21. **Region is deployment-specific** - Set via `AWS_DEFAULT_REGION` in `.scratchpad/ws-creds.env`; do not hardcode a region in scripts or templates
22. **Upstream nginx configs hardcode bare service hostnames** (e.g., `proxy_pass http://auth-server:8888/`). This only resolves in docker-compose (Docker DNS) and Terraform (Service Connect). CloudFormation uses Cloud Map DNS where only FQDNs resolve (e.g., `auth-server.mcp-gateway.local`). **Fix:** The entrypoint sed-replaces `auth-server:8888` in the generated nginx config with the host:port from `AUTH_SERVER_URL` env var, which the ECS task definition sets correctly per deployment mode. No-op for docker-compose/Terraform, activates only for CloudFormation. Must be re-applied after each upstream merge if `nginx_rev_proxy_*.conf` files change. Issue filed: #553.
23. **Ambiguous git refs break CodeBuild** - If a tag and branch share the same name (e.g., `v1.0.15`), `git push` fails and CodeBuild `SourceVersion` may resolve to the wrong ref. Use distinct branch names (e.g., `cloudformation/workshop-v1.0.15`) to avoid collision with upstream version tags.
24. **Docker Hub unauthenticated pull rate limits break parallel builds** - CodeBuild's shared NAT IP pool burns through Docker Hub's anonymous rate limit (100 pulls/6h) fast, especially with 10 parallel image builds. Upstream Dockerfiles (`Dockerfile.auth`, `Dockerfile.mcp-server`) reference `python:3.12-slim` (Docker Hub) while the CPU-optimized variants (`Dockerfile.registry-cpu`, `Dockerfile.mcp-server-cpu`) already use `public.ecr.aws/docker/library/python:3.12-slim`. **Fix:** Pre-pull from ECR Public in the buildspec pre_build phase, then `docker tag` it as the Docker Hub equivalent (`docker tag public.ecr.aws/.../python:3.12-slim python:3.12-slim`). Docker finds the image locally and skips the pull. Apply the same pattern for any new Docker Hub base image added upstream. Quay.io and Grafana images are pre-pulled directly (no rate limit issue observed).
25. **Entrypoint-only sed rewrites get overwritten by Python config regeneration** - The `nginx_service.py:generate_config()` method writes the complete nginx config on every regeneration (triggered by health checks, server toggle, etc.), overwriting any entrypoint sed changes. At startup: (1) Python generates config with 0 location blocks (servers health unknown), (2) `nginx -t` fails (bare `auth-server:8888` unresolvable via Cloud Map), (3) reload skipped, (4) entrypoint sed-rewrites and starts nginx. Later: health checks trigger regeneration → Python overwrites sed fix → `nginx -t` fails again → location blocks never added. **Fix:** Move auth-server URL replacement into `nginx_service.py:generate_config()` alongside other template variable replacements (`ROOT_PATH`, etc.), reading from `AUTH_SERVER_URL` env var. Runs on every regeneration. Keep entrypoint sed as safety net for initial static config. This is the companion fix to lesson #22 and must be re-applied after upstream merges that modify `nginx_service.py`.
26. **`scripts/codebuild/buildspec.yaml` must be carried forward on every version branch** - The CodeBuild project references `BuildSpec: scripts/codebuild/buildspec.yaml` from the GitHub repo checkout. This file lives outside the `cloudformation/` directory so it's easy to miss when porting. Early in a new version branch, use source-based GitHub builds (the `build-containers-workshop.sh` override or setting `Type: GITHUB` in compute-stack.yaml) so CodeBuild clones the repo and uses this buildspec. Once the branch is stable and verified, switch to the S3 pre-built container method (`NO_SOURCE` + inline buildspec that downloads tarballs from Workshop Studio S3 buckets). The buildspec includes the Docker Hub rate-limit workaround (lesson #24) and parallel builds for all 10 images.
27. **v1.0.16 Lambda API endpoint changes** - v1.0.16 changed several registry API endpoints: server delete changed from `DELETE /api/v1/servers/remove?name=` to `POST /api/servers/remove` with form data `path=`; agent delete changed from `DELETE /api/agents/remove?name=` to `DELETE /api/agents/{path}`; success responses changed from `{success: true}` to `{path, name, message}`. The MCPRegistration Lambda must be updated for these on every version upgrade. Also, the agent toggle endpoint (`/api/agents/{path}/toggle?enabled=true`) depends on an in-memory dict populated only during registration -- agents must be enabled immediately after registration in the same Lambda invocation, before any container restart clears the dict.
28. **Service Connect propagation delay requires a health gate Lambda** - CloudFormation marks ECS services as CREATE_COMPLETE before Service Connect (Envoy sidecar) hostnames propagate (~10-15 min). Any Lambda that depends on inter-service connectivity (e.g., MCPRegistration) must NOT run in the services-stack. Move it to a later stack (workshop-tools-stack) with a preceding health-gate Lambda that polls a canary endpoint until Service Connect is confirmed working. The health gate polls `GET /api/tools/{canary-server}/` and triggers `POST /api/refresh/{canary-server}/` until tools > 0.

---

## v1.0.12 -> v1.0.15 Upgrade Checklist

### New Environment Variables
| Variable | Purpose |
|----------|---------|
| `AUDIT_LOG_ENABLED` | Enable audit logging |
| `AUDIT_LOG_MONGODB_TTL_DAYS` | Audit log retention period (TTL days for audit_events collection) |
| `REGISTRY_ID` | Registry instance identifier |
| `FEDERATION_ENABLED` | Enable federation between registries |
| `FEDERATION_PEERS` | Comma-separated peer registry URLs |
| `REGISTRY_STATIC_TOKEN_AUTH_ENABLED` | Enable static token auth |
| `VECTOR_SEARCH_EF_SEARCH` | Vector search parameter |
| `OAUTH_STORE_TOKENS_IN_SESSION` | Store OAuth tokens in session |
| `REGISTRY_API_TOKEN` | Static API token for registry |
| `MAX_TOKENS_PER_USER_PER_HOUR` | Rate limiting |

### New Features to Evaluate for Workshop
- **Virtual MCP Servers** - Compose multiple real servers into virtual abstractions
- **Skills Registry** - Register and discover skills across servers
- **Federation** - Peer-to-peer registry discovery
- **Audit Logging** - Track all registry operations
- **A2A Discovery Simplification** - Simpler agent discovery config
- **IAM Settings UI** - In-app user/group/M2M management
- **Config Panel** - System configuration from UI
- **Security Scanner** - Enhanced skill security scanning

### New DocumentDB Collections
- `audit_events` - Audit log storage
- `mcp_peers` - Federation peer registry
- `mcp_federation_config` - Federation configuration
- `mcp_skills` - Skills registry
- `backend_sessions` - Backend session storage
- `virtual_servers` - Virtual server definitions

### Cherry-pick Status (Final)
All upstream PRs are now merged -- no cherry-picks needed for v1.0.15:
- PR #487 (capture_body multiline fix) -- merged via #529
- PR #488 (Lua metrics pipeline) -- CLOSED, folded into #544
- PR #498 (observability pipeline) -- CLOSED, folded into #544
- PR #544 (consolidated observability) -- MERGED by maintainer
- PR #548 (IPv6 Service Connect fix) -- MERGED by maintainer

---

## Carry-Forward Verification Checklist

> **CRITICAL: Two categories of fixes exist and they behave differently during upgrades.**
>
> - **Template-level fixes** live in `cloudformation/aws-ecs/templates/`. They travel with the
>   `cloudformation/` directory copy and survive version upgrades automatically.
> - **App-level code fixes** live in `registry/`, `docker/`, `scripts/`. They are **WIPED OUT**
>   every time a fresh branch is created from a new upstream tag. These MUST be re-applied
>   manually on every version upgrade unless they have been merged upstream.
>
> When verifying "absorbed (no diff)" during upgrade planning, be careful: an empty diff
> against the upstream tag means the upstream code is unchanged -- it does NOT mean our fix
> is present. For app-level fixes that are CloudFormation-deployment-specific (e.g., Cloud Map
> DNS rewrites), upstream will likely NEVER have these fixes because docker-compose and
> Terraform don't need them. Always verify by checking for the actual fix code, not by
> diffing against upstream.

### Template-Level Fixes (survive `cloudformation/` directory copy)

| # | Fix | File(s) | How to Verify |
|---|-----|---------|---------------|
| 1 | CloudFront X-Cloudfront-Forwarded-Proto header | compute-stack.yaml | Check OriginCustomHeaders on both CF distributions |
| 2 | EcsTasksSecurityGroup export name | services-stack.yaml | Check !ImportValue name matches network-stack export |
| 3 | DocumentDB Engine property | data-stack.yaml | `Engine: docdb` present |
| 4 | Nginx OAuth2 callback query param preservation | services-stack.yaml | Check nginx proxy_pass for auth callback |
| 5 | DocumentDB Init Lambda IAM PassRole | data-stack.yaml | PassRole Resource matches ECS task role ARN |
| 6 | STORAGE_BACKEND=documentdb | services-stack.yaml | All containers have correct env var |
| 7 | KeycloakRealmInit/DocumentDBInit race condition | services-stack.yaml | DependsOn ordering correct |
| 8 | Admin password from Secrets Manager | services-stack.yaml | SecretArn reference, not plaintext |
| 9 | Registry restart after Keycloak init | services-stack.yaml | Force-new-deployment Lambda exists |
| 10 | Dead Lambda code removed | services-stack.yaml | No orphaned Lambda functions |
| 11 | Password reset for existing users | services-stack.yaml | Keycloak init handles existing users |
| 12 | LOB user scopes in DocumentDB | data-stack.yaml | Init Lambda seeds all 3 scope docs |
| 39 | Pattern B URLs | content files | All curl commands use `/{server}/mcp` |
| 46 | IAM policy fixes | static/ | Policy v5 with all permission fixes |
| 47 | ADOT co-locate as sidecar | services-stack.yaml | ADOT container in metrics-service task |
| 48 | Pre-built containers (NOT for dev branch) | compute-stack.yaml | Dev branch uses GITHUB source |

### App-Level Code Fixes (WIPED by fresh branch from upstream tag -- re-apply manually)

> These fixes modify files OUTSIDE the `cloudformation/` directory. A fresh branch from
> an upstream tag will NOT have them. Check each one and re-apply if not yet upstreamed.

| # | Fix | File(s) | How to Verify | Upstream Status |
|---|-----|---------|---------------|-----------------|
| 22/25 | Nginx bare `auth-server:8888` -> Cloud Map FQDN | `registry/core/nginx_service.py`, `docker/registry-entrypoint.sh` | Grep for `AUTH_SERVER_URL` replacement in `nginx_service.py:generate_config()` AND entrypoint sed block | NOT upstreamed (CFN-only fix, issue #553) |
| 24 | Docker Hub rate limit workaround (ECR Public pre-pull) | `scripts/codebuild/buildspec.yaml` | Check pre_build phase for `public.ecr.aws` pull + `docker tag` | NOT upstreamed (CFN-only fix) |
| 573 | Datetime serialization in `GET /api/servers/groups/{name}` | `registry/api/server_routes.py` (~line 3298, `get_group_api`) | Check for `json.loads(json.dumps(group_data, default=str))` before `JSONResponse` | NOT upstreamed (issue #573 open). Cherry-picked `fb82ab3` → v1.0.16 `b42905c`. Blocks workshop Step 3.5 Step 2. |
| — | `list_groups()` return format mismatch (`scopes_groups` always empty) | `registry/repositories/documentdb/scope_repository.py` (~line 315), `registry/common/scopes_loader.py` (~line 49) | `list_groups()` returns `{"total_count": N, "groups": {...}}` not bare dict; `scopes_loader.py` unwraps via `.get("groups", groups_data)` | NOT upstreamed (no upstream issue filed yet). Cherry-picked `7844406` → v1.0.16 `991f52c`. Blocks workshop Step 3.5 Step 1 and IAM Groups panel. |
| #616 | `AgentCard.streaming` AttributeError in `discover_agents_by_skills` | `registry/api/agent_routes.py` (~line 1128) | `discover_agents_by_skills` reads `agent.streaming` but `AgentCard` has no `streaming` field (A2A stores it in `capabilities` dict). Crashes with 500 on every skill-based discovery that finds matches. Also: registration/update routes silently drop `streaming` by passing it as a top-level kwarg. Also: `provider` passes `AgentProvider` object where `str` expected. **Fix:** (1) read `agent.capabilities.get("streaming", False)`, (2) map `request.streaming` into `capabilities` dict, (3) extract `agent.provider.organization`. Pattern matches existing `list_agents` fix from `4812e21`. | Upstream bug (issue #616 filed). PR branch `fix/issue-616` pushed; also includes visibility `"internal"` -> `"private"` consistency fix. Fixed locally on v1.0.16 branch. |
| #618 | Agent enable/disable 500 after container restart | `registry/services/agent_service.py` (~line 316) | `enable_agent()` and `disable_agent()` only check in-memory dict; crash with ValueError if agent not loaded. After restart, registered agents are lost from memory. **Fix:** `_ensure_agent_loaded()` helper checks memory first, falls back to DB lookup via `self._repo.get(path)`. | Upstream bug (issue #618 filed). PR branch `fix/agent-toggle-restart` pushed. Fixed locally on v1.0.16 branch. Workshop workaround: Lambda enables agents immediately after registration in the same container lifecycle. |
| #619 | Agent enabled state not persisted to DocumentDB | `registry/services/agent_service.py` (~line 337, 367) | `enable_agent()`/`disable_agent()` call `save_state()` which is a **no-op** in DocumentDB backend. The `is_enabled` field in DB is never updated, so agents revert to disabled after container restart. `ServerService`, `SkillService`, and `VirtualServerService` all use `set_state()` correctly. **Fix:** Add `self._repo.set_state(path, True/False)` before `_persist_state()`. | Upstream bug (issue #619 filed). PR branch `fix/issue-619` pushed. **NOT fixed locally on v1.0.16 branch** -- workshop works around it via Lambda re-enable. Cherry-pick once merged upstream. |

---

## Open Issues

| Issue | Status | Description |
|-------|--------|-------------|
| #496 | OPEN | Health gate DNS -- unhealthy servers get commented-out nginx locations |
| #573 | OPEN (upstream), FIXED locally | `GET /api/servers/groups/{name}` returns 500 -- datetime not JSON serializable. Cherry-picked `fb82ab3` into v1.0.16 (`b42905c`). |
| — | UNFILED, FIXED locally | `GET /api/servers/groups` returns `scopes_groups: {}` -- `list_groups()` return format mismatch. Separate root cause from #573; needs its own upstream issue. Cherry-picked `7844406` into v1.0.16 (`991f52c`). |
| #616 | OPEN (upstream), FIXED locally | `POST /api/agents/discover` returns 500 -- `AgentCard` has no `streaming` attribute. Partial fix existed for `list_agents` since `4812e21`; `discover_agents_by_skills` was missed. Fixed all three locations (discovery crash, registration/update data loss, provider type mismatch). PR branch `fix/issue-616` pushed. |
| #618 | OPEN (upstream), FIXED locally | `PUT /api/agents/{path}/enable` returns 500 after container restart -- in-memory dict not populated. PR branch `fix/agent-toggle-restart` pushed. Workshop workaround: Lambda enables immediately after registration. |
| #619 | OPEN (upstream), NOT fixed locally | Agent `is_enabled` not persisted to DocumentDB -- `save_state()` is a no-op. Agents revert to disabled after restart. PR branch `fix/issue-619` pushed. Workshop masked by Lambda re-enable pattern. Cherry-pick onto workshop branch once merged upstream. |

---

## Resolved in v1.0.15 Cycle (Archive)

> Items below are fully resolved -- kept as historical reference only.
> They do NOT need to be re-applied on future version branches.

**Upstreamed app-level fixes (auto-inherited from new upstream tags):**
- #37/41: `capture_body.lua` multiline sanitization -- upstreamed via PR #529 (MERGED 2026-02-23)

**Closed upstream issues:**
- #491: codebuild.tf fork reference -- closed 2026-02-26 via PR #552 (MERGED). Fix confirmed.
- #547: IPv6 Service Connect DNS -- closed 2026-02-25 via PR #548 (MERGED). Fix confirmed.

**Closed/merged upstream PRs:**
- #487: capture_body multiline fix -- closed, superseded by maintainer PR #529 (MERGED). Fix landed.
- #488: Lua metrics pipeline -- closed, folded into PR #544 (MERGED).
- #498: Observability pipeline (TF) -- closed, folded into PR #544 (MERGED).
- #529: capture_body maintainer rewrite -- MERGED 2026-02-23 by aarora79.
- #544: Consolidated observability -- MERGED 2026-02-25 by aarora79.
- #548: IPv6 Service Connect fix -- MERGED 2026-02-25 by aarora79.
- #552: Fix codebuild source to upstream -- MERGED 2026-02-26.

---

## Architecture Reference

### Deployment Architecture
```
CloudFront (2) -> ALB (2) -> ECS Fargate -> DocumentDB + Aurora
                                         -> ADOT sidecar -> AMP -> Grafana
```

### Metrics Pipeline
```
nginx (emit_metrics.lua) -> metrics-service:8890 -> ADOT (localhost:9465 scrape) -> AMP -> Grafana
```

### Key File Paths
- Templates: `cloudformation/aws-ecs/templates/` (7 files: main, network, data, compute, services, observability-grafana, load-generator)
- Content: `cloudformation/aws-ecs/content/` (workshop modules)
- Scripts: `cloudformation/aws-ecs/scripts/` (load-generator, init scripts)
- Static: `cloudformation/aws-ecs/static/` (IAM policy, workshop assets)
- Grafana: `cloudformation/aws-ecs/grafana/` (dashboards, provisioning)

---

## v1.0.16 Task List (To Be Populated)

1. [x] Assess v1.0.12 -> v1.0.15 delta (docker-compose, terraform, docker/, registry/)
2. [x] Update services-stack.yaml env vars for new features (P2 complete: +11 registry env vars, +9 auth-server env vars, +1 auth-server secret)
3. [x] Update data-stack.yaml DocumentDB init for new collections (P3 complete: +2 env vars in containerOverrides -- STORAGE_BACKEND, AUDIT_LOG_MONGODB_TTL_DAYS)
4. [x] Verify compute-stack.yaml CodeBuild source and buildspec (P4 complete: all 10 images built, source defaults already WPrintz fork/v1.0.15)
5. [x] Test build and deploy in sandbox
6. [ ] Update workshop content for new features (Labs 4-10)
7. [x] Verify all 18 v1.0.12 fixes still present (P5 complete: 14 pass, 1 cosmetic, 2 auto-inherited, 1 behavior change. See .scratchpad/audit-v1012-fixes.md)
8. [ ] Create pre-built container branch when stable
