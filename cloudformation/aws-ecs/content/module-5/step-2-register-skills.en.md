---
title: "5.2 Register Skills"
weight: 62
---

Now you'll register skills of your own. Skills support visibility levels — `public`, `group`, and `private`.

## Internal Skills (Conceptual)

In an enterprise, teams create SKILL.md files in private repositories for proprietary workflows — code review standards, compliance checks, deployment runbooks, onboarding guides. These are registered with `group` visibility so only the team's Keycloak group can discover and download them.

The registration command looks like this:

:::code{language=bash showCopyAction=false}
curl -s -X POST "$REGISTRY_URL/api/skills" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "internal-code-review",
    "description": "Team code review standards and checklists",
    "skill_md_url": "https://github.your-corp.com/team/skills/blob/main/code-review/SKILL.md",
    "tags": ["code-review", "internal"],
    "visibility": "group"
  }' | jq .
:::

::alert[This is illustrative — don't run it. The URL points to a fictional internal repository. You'll register real skills in the next section.]{type="warning"}

The key difference is the `--visibility` flag:

| Visibility | Who Can See | Use Case |
|-----------|------------|----------|
| `public` | All authenticated users | Shared best practices, standard workflows |
| `group` | Users in the same Keycloak group | Team-specific processes, proprietary methods |
| `private` | Only the registering user | Personal workflows, experimental skills |

The group-based permissions from Lab 3 apply to skills too.

---

## Register Public Skills

Now let's register real skills from Anthropic's public `skills` repository. These use `public` visibility, so all authenticated users can discover and download them.

### Prerequisites: Get a JWT Token

You need a JWT token to authenticate CLI commands against the Registry API.

1. Open the MCP Gateway Registry in your browser (logged in as `admin`)
2. Click the **Get JWT Token** button in the top-left corner of the UI
3. In the dialog box that appears, click **Copy JSON**

:image[JWT Token dialog in the Registry UI]{src="/static/img/module-5/5_2/jwt-token-dialog.png" width=800}

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

### Step 1: Set Your Environment Variables

Set the Registry URL from the CloudFormation outputs (see [Lab 1, Step 1.2](/module-1/step-2-login) if you need a reminder):

:::code{language=bash showCopyAction=true}
export REGISTRY_URL=$(aws cloudformation describe-stacks --stack-name main-stack --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`MCPGatewayUrl`].OutputValue' --output text)
echo "Registry URL: $REGISTRY_URL"
:::

### Step 2: Register the Skills

Register three public skills from the `anthropics/skills` repository:

:::code{language=bash showCopyAction=true}
# Register pdf skill
curl -s -X POST "$REGISTRY_URL/api/skills" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "pdf",
    "description": "Create and manipulate PDF documents",
    "skill_md_url": "https://github.com/anthropics/skills/blob/main/skills/pdf/SKILL.md",
    "tags": ["pdf", "documents", "conversion"],
    "visibility": "public"
  }' | jq .
:::

You should see a JSON response confirming the registration:

:::code{language=json showCopyAction=false}
{
  "path": "pdf",
  "name": "pdf",
  "description": "Create and manipulate PDF documents",
  "skill_md_url": "https://github.com/anthropics/skills/blob/main/skills/pdf/SKILL.md",
  "skill_md_raw_url": "https://raw.githubusercontent.com/anthropics/skills/...",
  "tags": ["pdf", "documents", "conversion"],
  "visibility": "public",
  "owner": "admin",
  "is_enabled": true,
  "health_status": "unknown",
  ...
}
:::

Now register the remaining two skills:

:::code{language=bash showCopyAction=true}
# Register xlsx skill
curl -s -X POST "$REGISTRY_URL/api/skills" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "xlsx",
    "description": "Create and manipulate Excel spreadsheets",
    "skill_md_url": "https://github.com/anthropics/skills/blob/main/skills/xlsx/SKILL.md",
    "tags": ["spreadsheet", "excel", "xlsx", "data"],
    "visibility": "public"
  }' | jq .
:::

:::code{language=bash showCopyAction=true}
# Register mcp-builder skill
curl -s -X POST "$REGISTRY_URL/api/skills" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mcp-builder",
    "description": "Build MCP servers and tools for AI assistant integrations",
    "skill_md_url": "https://github.com/anthropics/skills/blob/main/skills/mcp-builder/SKILL.md",
    "tags": ["mcp", "coding", "development", "servers"],
    "visibility": "public"
  }' | jq .
:::

Verify each response shows the correct `name` and `"is_enabled": true`.

---

### Step 3: Verify Health

Run a health check to confirm the SKILL.md files are accessible at their source URLs:

:::code{language=bash showCopyAction=true}
curl -s "$REGISTRY_URL/api/skills/pdf/health" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  | jq .
:::

You should see output confirming the skill is healthy:

:::code{language=json showCopyAction=false}
{
  "path": "pdf",
  "healthy": true,
  "status_code": 200,
  "error": null,
  "response_time_ms": 245
}
:::

`"healthy": true` means the SKILL.md is reachable at its source URL. If it were `false`, the repository might be private, the URL changed, or the file was deleted.

---

## What Happened Behind the Scenes

For each skill you registered, the Registry:

1. **Created a registration record** in DocumentDB (`mcp_skills` collection)
2. **Set visibility to `public`** — all authenticated users can see these skills regardless of group membership
3. **Set health to `unknown`** — until you explicitly ran the health check

When you ran the health check, the Registry:

1. **Fetched the SKILL.md URL** via HTTP GET
2. **Verified the response** — HTTP 200 with non-empty content
3. **Updated the health status** in DocumentDB from `unknown` to `healthy`

---

## Validation

1. Return to the Skills section in the Registry UI
2. Confirm all three new skills appear: `pdf`, `xlsx`, and `mcp-builder`
3. You should now see **5 total skills** — 2 pre-deployed + 3 you just registered
4. Verify each new skill shows `public` visibility

:image[Skills catalog showing all five skills including the three newly registered]{src="/static/img/module-5/5_2/skills-registered.png" width=800}

---

## Challenge: Health Check the Other Skills

You ran a health check for the `pdf` skill. Can you run health checks for `xlsx` and `mcp-builder` on your own?

::::expand{header="Hint: Health Check Commands"}
:::code{language=bash showCopyAction=true}
curl -s "$REGISTRY_URL/api/skills/xlsx/health" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  | jq .

curl -s "$REGISTRY_URL/api/skills/mcp-builder/health" \
  -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  | jq .
:::

Both should return `"healthy": true` since they point to real, publicly accessible SKILL.md files in the Anthropic skills repository.
::::

:button[Next: Use Skills in Coding Environment]{href="/module-5/step-3-use-skill-locally"}
