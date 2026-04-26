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
<!-- Row 12 was misclassified as template-level; moved to app-level table below. See lesson #37. -->
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
| 37 | LOB demo scopes in DocumentDB init | `scripts/init-documentdb-indexes.py`, `scripts/registry-users-lob1.json`, `scripts/registry-users-lob2.json` | See lesson #37 below. **Quick check:** `ls scripts/registry-users-lob*.json` should return 2 files AND `grep -c "registry-users-lob" scripts/init-documentdb-indexes.py` should return >=2. If either fails, re-port per lesson #37. | NOT upstreamed (upstream deliberately bootstraps admin only -- see steering log #35 for the rationale). Re-ported on v1.0.20 in commit `3fa7f147`. |
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

---

## v1.0.20 Upgrade Checklist

*Progress and working notes: `.scratchpad/cloudformation-workshop-v1.0.20-steering-log.md`*

### Corrections to Earlier Lessons

- **Lesson #26 path correction:** the buildspec lives at `cloudformation/aws-ecs/scripts/codebuild/buildspec.yaml` (inside the ported `cloudformation/` dir), NOT at repo-root `scripts/codebuild/`. It survives the cloudformation dir copy and is NOT wiped by a fresh branch from the upstream tag. Verified 2026-04-25 on v1.0.20 port.
- **Workshop `CLAUDE.md.bak` reference is stale** — file is not tracked on any workshop branch. The "Version Upgrade Warning" block should either commit the file or drop the reference.

### New Universal Lessons (from v1.0.20 cycle)

29. **Track which app-level fixes graduate to upstream on each release.** On v1.0.20 cycle, issues #573, #616, #618, #619, and the `list_groups` format mismatch ALL landed upstream — 5 of the 7 app-level fixes in the table above. Re-applying them blindly would have wasted effort and risked diverging from upstream. **Verification pattern:** grep for the fix's distinctive code shape (e.g., `json.loads(json.dumps(..., default=str))`, `_ensure_agent_loaded`, `self._repo.set_state(path, True)`, `agent.capabilities.get("streaming", False)`, bare-dict return from `list_groups()`) before cherry-picking.
30. **Cherry-pick specific commits, not branch tips.** `git cherry-pick cloudformation/workshop-v<prev>` fails when the branch tip is a merge commit. Use `git log --oneline cloudformation/workshop-v<prev> -- <file>` to find the specific fix commit and cherry-pick that.
31. **`Dockerfile.metrics-db` is a docker-compose convenience; do NOT add to Fargate buildspec or task def.** metrics-service bundles `aiosqlite` (pure-Python) and writes directly to `SQLITE_DB_PATH`. Workshop uses `/tmp/metrics.db` (world-writable, ephemeral, survives non-root UID 1000). This is an intentional divergence from upstream's sidecar-on-shared-volume pattern.
32. **Registry startup validation uses Pydantic defaults.** `registry/main.py:410-424` raises on empty `REGISTRY_URL`, `REGISTRY_NAME`, `REGISTRY_ORGANIZATION_NAME`, but `config.py` provides defaults (`http://localhost:8000`, `AI Registry`, `ACME Inc.`). Missing env vars do NOT crash the container but produce a misleading federation registry card. Always set these three explicitly in the Registry task def.
33. **Lambda endpoint drift is cycle-dependent, not guaranteed.** v1.0.20 had zero endpoint drift (vs v1.0.16's breaking changes per lesson #27). Always audit by cross-referencing `grep -n '@router\.' registry/api/*_routes.py` against the Lambda's `urllib.request.Request(...)` URLs in `workshop-tools-stack.yaml`.
34. **`.env.example` entries aren't definitive.** They show *suggested* values but may not match the Pydantic default in `registry/core/config.py`. Prefer reading `config.py` for ground truth when deciding whether an env var is required.
35. **On every workshop version branch, bump the GitHub branch defaults that drive CodeBuild.** CodeBuild clones the fork based on parameter defaults in the templates — if left at the prior version, the build silently pulls old source even after templates, content, and env vars are updated. There are at least two places to update (more may appear over time; grep to be sure):
    - `cloudformation/aws-ecs/templates/compute-stack.yaml` — `GitHubBranch` parameter `Default:` value. This is the one CodeBuild actually reads for `SourceVersion`.
    - `cloudformation/aws-ecs/scripts/export-containers.sh` — `SOURCE_VERSION` and `IMAGE_TAG` defaults (pre-built tarball path only, but keep consistent).
    - Also verify `GitHubRepoUrl` in compute-stack.yaml still points at the correct fork if fork ownership ever changes.
    - **How to find every reference:** `grep -rn "workshop-v1\." cloudformation/aws-ecs/` plus `grep -rn "workshop-v1\." cloudformation/aws-ecs/scripts/`. Expect content markdown files to also reference the version (e.g., module docs describing the template inputs) — those usually don't control the build but should stay consistent.
    - **Verification after bump:** look at the CodeBuild project's Source config in the AWS console (or `aws codebuild batch-get-projects`) and confirm `sourceVersion` shows the new branch before starting a build. The template default is only read on stack create/update — an already-deployed stack keeps the old value unless you pass the new default explicitly or update the stack.
36. **Buildspec (`cloudformation/aws-ecs/scripts/codebuild/buildspec.yaml`) hardcodes image names, not branch names.** The buildspec references `docker/Dockerfile.*` by relative path against the repo checkout CodeBuild produces from `SourceVersion`. It does NOT embed a branch or tag. So as long as lesson #35 is applied, the buildspec does not need editing per version. **But** check that any new `docker/Dockerfile.*` added upstream (e.g., v1.0.20 added `Dockerfile.metrics-db`) is either added to the parallel build block OR intentionally skipped with a documented reason (v1.0.20: skipped — inline aiosqlite used instead; see lesson #31).

37. **Every workshop version branch must re-port the LOB scope DocumentDB seeds.** Upstream `scripts/init-documentdb-indexes.py:_load_default_scopes()` loads exactly one scope file (`registry-admins.json`). It does NOT load the `registry-users-lob1` / `registry-users-lob2` scopes that Module 3 assumes exist. Without this fix, any LOB user (`lob1-user`, `lob2-user`, `lob1-bot`, `lob2-bot`) logs in and sees zero servers — their Keycloak groups exist (CFN bootstraps those) but no matching doc lives in the `mcp_scopes` DocumentDB collection for `scope_repository.get_group_mappings()` to find. **Why upstream won't fix:** the maintainer's stated position (in `terraform/aws-ecs/scripts/run-documentdb-init.sh:215-218`) is that `registry-admins` is "sufficient to bootstrap the system" and production deployments should create their own orgs via the registry API. This is consistent for prod multi-tenant use but breaks out-of-box workshop demos. **Why this keeps regressing across cycles:** the fix files (`scripts/registry-users-lob*.json` + the `scripts/init-documentdb-indexes.py` delta) all live OUTSIDE `cloudformation/`, so the "port the cloudformation dir" step from lesson #26 doesn't carry them. **Fix recipe (copy-paste ready):**
    1. `git show cloudformation/workshop-v1.0.20:scripts/registry-users-lob1.json > scripts/registry-users-lob1.json`
    2. `git show cloudformation/workshop-v1.0.20:scripts/registry-users-lob2.json > scripts/registry-users-lob2.json`
    3. In `scripts/init-documentdb-indexes.py`, find `_load_default_scopes()`. Replace the `admin_scope_file = script_dir / "registry-admins.json"` single-file block with a loop over `scope_files = ["registry-admins.json", "registry-users-lob1.json", "registry-users-lob2.json"]`. Guard the Entra ID group mapping with `if entra_group_id and scope_doc.get("_id") == "registry-admins":` so it only applies to the admin scope. Reference implementation is the v1.0.20 commit `3fa7f147`.
    4. **Critical:** the JSON files MUST use `airegistry-tools` for the shared registry server name, NOT `mcpgw`. The v1.0.20 upstream `scopes.yml` still references `mcpgw` (stale), but the actual registered server path in all workshop deploys is `/airegistry-tools/`. Verify with: `curl -H "Authorization: Bearer <m2m-token>" ${GATEWAY_URL}/api/servers | jq -r '.servers[].path'`. If you see `/mcpgw/`, upstream renamed it back and you'll need to rename in the JSON too.
    5. **Only `list_service` and `health_check_service`** UI permission keys are consumed by v1.0.20 code. The historical `list_tools` / `call_tool` / `get_service` keys in the v1.0.16 JSONs are dead weight — omit them.
    6. **Do NOT cherry-pick the v1.0.15 commit (`7844406c`) or v1.0.16 rename commit (`9278ffcb`) directly** — they carry unrelated fixes (module-2 content edits, `scopes_loader` / `list_groups` changes) that either drifted or landed upstream in later cycles and would conflict. Recreating the two JSON files + the init-script loop is faster and cleaner than surgical cherry-pick.
    7. **Validation:** after deploy, run `.scratchpad/speedrun-modules-2-3.sh`. The script is idempotent; the last three `OK` lines must show "`lob1-bot sees exactly 3 expected servers`", "`Allowed tool -> HTTP 200`", "`Denied tool  -> HTTP 403`". If the scope seed fix is missing, lob1-bot will see `[]` and both tool calls will 404 or return the empty-scope behavior. If the seed fix is in place but stale (wrong server name), lob1-bot will see 2 servers instead of 3.
    8. **Speedrun vs. seed-fix division of labor:** the seed-fix covers 2 of the 4 prereq API calls (lob1/lob2 scope docs exist at deploy time). The speedrun script still handles the other 2: registering + enabling `cloudflare-docs` (Module 2.2/2.3 content) and adding `lob1-user` to `registry-users-lob2` (Module 3.3 Part A). Keep both.

### v1.0.20 Task List

1. [x] Fast-forward fork `main` to upstream `9ffd3735`; push tags v1.0.17-v1.0.20
2. [x] Create branch `cloudformation/workshop-v1.0.20` from tag `v1.0.20`; port `cloudformation/` + `CLAUDE.md` from workshop-v1.0.16
3. [x] Diff v1.0.16 -> v1.0.20 (249 commits): 37 new env vars, 5 new API route modules, new Dockerfile.metrics-db, +1107 line agentcore federation client
4. [x] Re-apply app-level fixes: only lesson #22/#25 nginx FQDN needed (cherry-picked `f101ee8b`); #573, #616, #618, #619, list_groups all upstreamed
5. [x] Audit MCPRegistration Lambda against v1.0.20 routes - ZERO drift across 12 endpoints
6. [x] Add new env vars to services-stack.yaml (6 needed: REGISTRY_URL/NAME/ORGANIZATION_NAME/DESCRIPTION, M2M_DIRECT_REGISTRATION_ENABLED, MCP_TELEMETRY_HEARTBEAT_INTERVAL_MINUTES)
7. [x] Evaluate Dockerfile.metrics-db - skip (Fargate uses inline aiosqlite)
8. [x] Bump CodeBuild branch defaults (lesson #35): compute-stack.yaml `GitHubBranch`, export-containers.sh `SOURCE_VERSION`/`IMAGE_TAG`. Commit `d813b2d9`
9. [x] Audit `scripts/codebuild/buildspec.yaml` for new/removed Dockerfiles (lesson #36): no changes needed -- Dockerfile.metrics-db intentionally skipped
10. [x] Re-port LOB demo scope seed files + init-script loop (lesson #37). Commit `3fa7f147` added `scripts/registry-users-lob1.json`, `scripts/registry-users-lob2.json`, and extended `scripts/init-documentdb-indexes.py:_load_default_scopes()`. Validated via `.scratchpad/speedrun-modules-2-3.sh` (3 servers + 200/403 enforcement).
10. [ ] Sandbox deploy from GitHub source, verify all containers come up
11. [ ] Test Ravi's skills module (content/module-5/) end-to-end
12. [ ] Walk modules 1-5 against v1.0.20 UI; update verbiage + screenshots (especially `static/img/module-1/1_2/Registry_login_page.png` after PR #591 removed local login toggle)
13. [ ] Switch CodeBuild to pre-built tarballs; regenerate container tarballs; upload to Workshop Studio S3 (deferred until branch stable)
14. [ ] Run `.scratchpad/stage-workshop-assets.sh` to push to Workshop Studio gitlab repo
