---
title: "4.3 Register Public Skills"
weight: 53
---

Import official skills from Anthropic's public skills repository and verify they are accessible. Unlike the internal skill from the previous step, these skills point to real, publicly accessible SKILL.md files — so the health checks will succeed.

## Step 1: Register Anthropic Skills

Register four public skills from the `anthropics/skills` repository. Each command registers one skill with `public` visibility:

:::code{language=bash showCopyAction=true}
# Register pdf skill
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-register \
  --name pdf \
  --url "https://github.com/anthropics/skills/blob/main/skills/pdf/SKILL.md" \
  --description "Create and manipulate PDF documents" \
  --tags pdf,documents,conversion \
  --visibility public
:::

:::code{language=bash showCopyAction=true}
# Register xlsx skill
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-register \
  --name xlsx \
  --url "https://github.com/anthropics/skills/blob/main/skills/xlsx/SKILL.md" \
  --description "Create and manipulate Excel spreadsheets" \
  --tags spreadsheet,excel,xlsx,data \
  --visibility public
:::

:::code{language=bash showCopyAction=true}
# Register docx skill
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-register \
  --name docx \
  --url "https://github.com/anthropics/skills/blob/main/skills/docx/SKILL.md" \
  --description "Create and manipulate Microsoft Word documents" \
  --tags docs,word,docx,documents \
  --visibility public
:::

:::code{language=bash showCopyAction=true}
# Register mcp-builder skill
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-register \
  --name mcp-builder \
  --url "https://github.com/anthropics/skills/blob/main/skills/mcp-builder/SKILL.md" \
  --description "Build MCP servers and tools for AI assistant integrations" \
  --tags mcp,coding,development,servers \
  --visibility public
:::

After each command, you should see a success response with the skill metadata. For example:

:::code{language=json showCopyAction=false}
{
  "status": "success",
  "skill": {
    "name": "pdf",
    "visibility": "public",
    "tags": ["pdf", "documents", "conversion"],
    "health": "unknown"
  }
}
:::

---

## Step 2: Verify Health

Run a health check to confirm the SKILL.md files are accessible at their source URLs:

:::code{language=bash showCopyAction=true}
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-health --path pdf
:::

You should see output confirming the skill is healthy:

:::code{language=json showCopyAction=false}
{
  "name": "pdf",
  "health": "healthy",
  "url": "https://github.com/anthropics/skills/blob/main/skills/pdf/SKILL.md"
}
:::

A **healthy** skill means the Registry successfully fetched the SKILL.md content from the source URL. An **unhealthy** skill might indicate the repository is private, the URL has changed, or the file was deleted.

::alert[Health checks verify that the SKILL.md source is reachable. This is the same concept as MCP server health checks in Lab 2 — the Registry monitors the availability of registered resources. The difference is that server health checks use the MCP `initialize` protocol, while skill health checks use a simple HTTP GET.]{type="info"}

---

## What Happened Behind the Scenes

For each skill you registered, the Registry:

1. **Created a registration record** in DocumentDB (`mcp_skills` collection)
2. **Set visibility to `public`** — all authenticated users can see these skills regardless of group membership
3. **Set health to `unknown`** — until you explicitly ran the health check

When you ran `skill-health`, the Registry:

1. **Fetched the SKILL.md URL** via HTTP GET
2. **Verified the response** — HTTP 200 with non-empty content
3. **Updated the health status** in DocumentDB from `unknown` to `healthy`

| Skill | Health Before | Health After | Why |
|-------|---------------|--------------|-----|
| `internal-code-review` | unknown | unknown | Fictional URL, no health check run |
| `pdf` | unknown | healthy | Real URL, health check passed |
| `xlsx` | unknown | unknown | No health check run yet |
| `docx` | unknown | unknown | No health check run yet |
| `mcp-builder` | unknown | unknown | No health check run yet |

---

## Validation

1. Return to the Skills section in the Registry UI
2. Confirm all four public skills appear: `pdf`, `xlsx`, `docx`, `mcp-builder`
3. Verify each shows `public` visibility
4. Check the health status column — `pdf` should show healthy; others may still show unknown until health-checked

:image[Skills catalog showing all four public skills with healthy status]{src="/static/img/module-4/4_3/public-skills-registered.png" width=800}

---

## Challenge: Health Check All Skills

You ran a health check for the `pdf` skill. Can you run health checks for the remaining public skills (`xlsx`, `docx`, `mcp-builder`) on your own?

::::expand{header="Hint: Health Check Commands"}
:::code{language=bash showCopyAction=true}
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-health --path xlsx

uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-health --path docx

uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-health --path mcp-builder
:::

All three should return `healthy` since they point to real, publicly accessible SKILL.md files in the Anthropic skills repository.
::::

:button[Next: Use Skills in Coding Environment]{href="/module-4/step-4-use-skill-locally"}
