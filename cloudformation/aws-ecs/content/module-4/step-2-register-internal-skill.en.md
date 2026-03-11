---
title: "4.2 Register an Internal Skill"
weight: 52
---

Register a team-scoped skill that represents an internal workflow, such as a corporate code review process. This demonstrates how enterprises can share proprietary AI assistant behaviors within specific teams while keeping them hidden from others.

## Prerequisites: Get a JWT Token

You need a JWT token to authenticate CLI commands against the Registry API.

1. Open the MCP Gateway Registry in your browser (logged in as `admin`)
2. Click the **Get JWT Token** button in the top-left corner of the UI
3. In the dialog box that appears, click **Copy JSON**

:image[JWT Token dialog in the Registry UI]{src="/static/img/module-4/4_2/jwt-token-dialog.png" width=800}

4. Save the copied JSON to a `.token` file in your working directory:

:::code{language=bash showCopyAction=true}
# Paste the copied JSON into the .token file
cat > .token << 'EOF'
<paste JSON here>
EOF
:::

5. Verify the token file:

:::code{language=bash showCopyAction=true}
jq -r '.tokens.access_token' .token | head -c 50
# Should show the first 50 characters of your token
:::

You should see output like:

:::code{language=text showCopyAction=false}
eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lk
:::

::alert[The JWT token expires after a set period. If you get authentication errors later in the lab, repeat this step to get a fresh token.]{type="warning"}

---

## Step 1: Set Your Registry URL

:::code{language=bash showCopyAction=true}
# Use your Registry URL from the CloudFormation outputs (Lab 1)
REGISTRY_URL="https://<your-registry-url>"
:::

::alert[**Tip:** You can find your Registry URL in the CloudFormation outputs. See [Lab 1, Step 1](/module-1/step-1-cloudformation-outputs) if you need a reminder.]{type="info"}

## Step 2: Register the Internal Skill

Register a skill with `group` visibility so only your team can see it:

:::code{language=bash showCopyAction=true}
uv run python api/registry_management.py \
  --registry-url "$REGISTRY_URL" \
  --token-file .token \
  skill-register \
  --name internal-code-review \
  --url "https://github.com/corp/skills/blob/main/code-review/SKILL.md" \
  --visibility group \
  --tags code-review,internal
:::

You should see output confirming the registration:

:::code{language=json showCopyAction=false}
{
  "status": "success",
  "skill": {
    "name": "internal-code-review",
    "visibility": "group",
    "tags": ["code-review", "internal"],
    "health": "unknown"
  }
}
:::

Let's break down the key fields:

| Field | Value | Purpose |
|-------|-------|---------|
| `--name` | `internal-code-review` | Unique identifier, used in slash commands and API calls |
| `--url` | GitHub SKILL.md URL | Source location the Registry fetches content from |
| `--visibility` | `group` | Only users in the same Keycloak group can see this skill |
| `--tags` | `code-review,internal` | Keywords for search and filtering |

::alert[Setting visibility to `group` restricts this skill to users in the same Keycloak group. This follows the same access control model you explored in Lab 3 — the same group-based permissions that control MCP server visibility also control skill visibility.]{type="info"}

---

## What Happened Behind the Scenes

When you ran the `skill-register` command, the Registry:

1. **Created a registration record** in DocumentDB (`mcp_skills` collection) with the skill name, URL, visibility, and tags
2. **Set health to `unknown`** — the Registry hasn't checked whether the SKILL.md URL is accessible yet
3. **Applied visibility rules** — only users whose Keycloak groups match the registering user's groups will see this skill

This is analogous to MCP server registration in Lab 2, where the server started in a disabled state. For skills, the equivalent is the `unknown` health status — the Registry knows the skill exists but hasn't verified the source is reachable.

---

## Validation

1. Return to the Skills section in the Registry UI
2. Confirm `internal-code-review` appears in the list
3. Verify the visibility is set to `group`

:image[Skills list showing internal-code-review with group visibility]{src="/static/img/module-4/4_2/internal-skill-registered.png" width=800}

::alert[The skill's health status will show `unknown` because the URL points to a fictional repository. In a real enterprise, this would point to your organization's internal GitHub or GitLab instance.]{type="info"}

:button[Next: Register Public Skills]{href="/module-4/step-3-register-public-skills"}
