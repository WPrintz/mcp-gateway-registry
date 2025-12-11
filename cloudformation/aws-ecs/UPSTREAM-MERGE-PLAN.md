# Upstream Merge Plan: v1.0.6 → v1.0.7

## Overview

Merge upstream `v1.0.7` changes into `feature/cloudformation-deployment` branch while preserving workshop-specific customizations.

**Target:** Pin workshop at upstream v1.0.7
**Upstream repo:** https://github.com/agentic-community/mcp-gateway-registry.git
**Current branch:** `feature/cloudformation-deployment` (based on v1.0.6)

---

## Pre-Merge Checklist

- [ ] Clean up uncommitted files (see Step 0 below)
- [ ] Commit workshop-related changes
- [ ] Create backup branch: `git branch backup/pre-v1.0.7-merge`
- [ ] Fetch latest upstream: `git fetch upstream`

---

## Files with Conflicts (3 files)

### 1. `docker/Dockerfile.mcp-server`

| Aspect | Our Change | Upstream Change |
|--------|------------|-----------------|
| Base image | `public.ecr.aws/docker/library/python:3.12-slim` | `python:3.12-slim` (Docker Hub) |
| Build args | None | `ARG SERVER_DIR` for flexible build context |
| Registry module | Not copied | Copies `registry/` module for embeddings |

**Resolution Strategy:** MERGE BOTH
- Keep our ECR Public base image (avoids Docker Hub rate limits)
- Add upstream's `SERVER_DIR` build arg and registry module copy logic

**Merged Result:**
```dockerfile
FROM public.ecr.aws/docker/library/python:3.12-slim  # OURS

ARG SERVER_DIR  # UPSTREAM

# ... rest of upstream's changes ...
```

---

### 2. `auth_server/server.py`

| Aspect | Our Change | Upstream Change |
|--------|------------|-----------------|
| Secure cookie | Based on `redirect_url.startswith("https://")` | Based on `x-forwarded-proto` header |
| Cookie domain | Not configurable | Configurable via config |
| Logging | Basic | Detailed cookie param logging |

**Resolution Strategy:** ACCEPT UPSTREAM
- Upstream's implementation is more comprehensive
- Includes `x-forwarded-proto` handling (important for ALB)
- Our change was a subset of what upstream now provides

**Action:** Accept upstream version entirely (no manual merge needed)

---

### 3. `docker-compose.yml`

| Aspect | Our Change | Upstream Change |
|--------|------------|-----------------|
| Volume paths | `${HOME}/mcp-gateway/...` → `./mcp-gateway/...` | No change to paths |
| Env vars | Added `POLYGON_API_KEY` | Added 7 embeddings env vars |
| metrics-service | No change | Changed build context |
| mcpgw-server | No change | Added `SERVER_DIR` build arg |

**Resolution Strategy:** MERGE BOTH
- Keep our relative path changes (`./mcp-gateway/...`)
- Keep our `POLYGON_API_KEY` addition
- Add upstream's embeddings configuration
- Add upstream's build context changes

---

## Files with No Conflicts

These files changed upstream but we didn't modify them - they'll merge cleanly:

| Directory | Changes |
|-----------|---------|
| `registry/` | Agent rating system, embeddings provider, search improvements |
| `frontend/` | AgentCard.tsx, StarRatingWidget.tsx |
| `docs/` | Cookie security design doc, embeddings doc |
| Various `uv.lock` | Deleted (cleanup) |
| `release-notes/` | v1.0.6.md added |

---

## Workshop-Specific Files (No Conflicts)

Our `cloudformation/aws-ecs/` directory doesn't exist upstream - completely safe:

- `templates/*.yaml` - All CloudFormation templates
- `lambda/` - Custom Lambda functions
- `scripts/` - Deployment scripts
- `*.md` - Documentation

---

## Merge Procedure

### Step 0: Pre-Merge Cleanup

**Files to REVERT (local laptop testing, not needed):**
```bash
git checkout -- auth_server/scopes.yml
git checkout -- config/grafana/dashboards/mcp-analytics-comprehensive.json
git checkout -- frontend/package-lock.json
git checkout -- metrics-service/app/otel/exporters.py
git checkout -- servers/fininfo/uv.lock
git checkout -- uv.lock
```

**Files to DELETE (local artifacts):**
```bash
rm -f docs/fininfo-transport-issue.md
rm -f terraform/aws-ecs/plan.tfplan
```

**Files to KEEP and COMMIT:**
```bash
# Workshop CloudFormation (all files in this directory)
git add cloudformation/aws-ecs/

# Workshop scripts
git add scripts/

# Workshop docs
git add docs/ssm-secrets-security-review.md
git add DEMO-RUNBOOK.md

# Kiro specs and tasks
git add .kiro/

# Commit workshop files before merge
git commit -m "Pre-merge: Commit workshop-specific files

- CloudFormation templates and scripts
- Workshop documentation
- Kiro specs and tasks"
```

**Files to handle during merge (have local changes):**
- `docker-compose.yml` - Will be merged with upstream
- `cloudformation/aws-ecs/templates/network-stack.yaml` - Workshop file, keep ours

### Step 1: Create Backup
```bash
git branch backup/pre-v1.0.7-merge
git log --oneline -1  # Note current commit
```

### Step 2: Fetch and Merge
```bash
git fetch upstream
git merge upstream/main --no-commit
```

### Step 3: Resolve Conflicts

**File 1: docker/Dockerfile.mcp-server**
```bash
# Open file, manually merge:
# - Line 5: Keep ECR Public base image
# - Add SERVER_DIR and registry copy logic from upstream
git add docker/Dockerfile.mcp-server
```

**File 2: auth_server/server.py**
```bash
# Accept upstream version
git checkout --theirs auth_server/server.py
git add auth_server/server.py
```

**File 3: docker-compose.yml**
```bash
# Open file, manually merge:
# - Keep our relative paths (./mcp-gateway/...)
# - Keep our POLYGON_API_KEY
# - Add upstream's embeddings vars and build changes
git add docker-compose.yml
```

### Step 4: Complete Merge
```bash
git commit -m "Merge upstream v1.0.7 into cloudformation-deployment

Conflicts resolved:
- docker/Dockerfile.mcp-server: Keep ECR Public base + add SERVER_DIR
- auth_server/server.py: Accept upstream cookie security improvements
- docker-compose.yml: Merge relative paths + embeddings config"
```

### Step 5: Verify
```bash
# Check CloudFormation templates still valid
cd cloudformation/aws-ecs
# Run any validation scripts

# Test docker-compose locally if possible
docker-compose config
```

---

## Post-Merge Tasks

- [ ] Update version references in scripts to v1.0.7
- [ ] Update `export-ecr-images.sh` default version
- [ ] Rebuild container images with merged code
- [ ] Test deployment in workshop account
- [ ] Update tasks.md with completion status

---

## Rollback Plan

If merge causes issues:
```bash
git reset --hard backup/pre-v1.0.7-merge
git push --force-with-lease origin feature/cloudformation-deployment
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Merge conflicts break build | Low | High | Backup branch, test before push |
| Cookie changes affect auth | Low | Medium | Upstream tested; ALB handles proto |
| Embeddings config missing | Low | Low | Optional feature, defaults work |

**Overall Risk: LOW** - All conflicts are complementary, not opposing changes.
