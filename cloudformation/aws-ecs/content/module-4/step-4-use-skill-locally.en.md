---
title: "4.4 Use Skills in Coding Environment"
weight: 54
---

Download a registered skill from the Registry and use it in Claude Code. This step demonstrates the end-to-end workflow: discover a skill in the Registry, pull it to your local environment, and invoke it in an AI coding assistant.

## Step 1: Download a Skill

Fetch the skill content from the Registry API and save it to the Claude Code skills directory:

:::code{language=bash showCopyAction=true}
mkdir -p ~/.claude/skills/pdf
curl -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  $REGISTRY_URL/api/skills/pdf/content \
  | jq -r '.content' > ~/.claude/skills/pdf/SKILL.md
:::

The API response contains the full SKILL.md text. The `jq -r '.content'` extracts the raw content and writes it to the local skills directory.

## Step 2: Verify the Download

:::code{language=bash showCopyAction=true}
# Check the file exists and has content
wc -l ~/.claude/skills/pdf/SKILL.md
head -20 ~/.claude/skills/pdf/SKILL.md
:::

You should see output like:

:::code{language=text showCopyAction=false}
      85 /Users/you/.claude/skills/pdf/SKILL.md
# PDF Generation Skill

This skill helps you create and manipulate PDF documents...
:::

:image[Terminal output showing downloaded SKILL.md content]{src="/static/img/module-4/4_4/skill-download-verify.png" width=800}

The file contains the structured instructions that tell the AI assistant how to handle PDF operations — including required libraries, formatting conventions, and step-by-step workflows.

---

## Step 3: Invoke the Skill

In Claude Code, invoke the skill using its slash command:

:::code{language=bash showCopyAction=true}
/pdf
:::

:image[Claude Code with the pdf skill invoked]{src="/static/img/module-4/4_4/claude-code-skill-invoked.png" width=800}

The AI assistant reads the SKILL.md instructions and follows the defined workflow for PDF operations. The skill provides context, best practices, and step-by-step guidance that the assistant uses to produce better results.

::alert[Skills are behavioral guidance, not executable tools. When you invoke `/pdf`, the assistant doesn't call an API — it reads the instructions and applies them to your request. This is fundamentally different from MCP tools (Lab 2), which execute functions and return results.]{type="info"}

---

## What Happened Behind the Scenes

The download-and-invoke flow works like this:

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│  1. curl API call   │────►│  Registry API        │────►│  DocumentDB         │
│     with JWT token  │     │  validates token,    │     │  mcp_skills         │
│                     │     │  fetches content     │     │  collection         │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
         │
         ▼
┌─────────────────────┐     ┌─────────────────────┐
│  2. SKILL.md saved  │────►│  3. /pdf invoked     │
│     to ~/.claude/   │     │     in Claude Code   │
│     skills/pdf/     │     │     AI reads & acts  │
└─────────────────────┘     └─────────────────────┘
```

| Step | What Happens |
|------|-------------|
| **API call** | Your `curl` sends a JWT-authenticated request to the Registry API |
| **Token validation** | Registry validates the JWT and checks your permissions |
| **Content fetch** | Registry retrieves the SKILL.md content from the `mcp_skills` collection |
| **Local save** | `jq` extracts the content and writes it to the Claude Code skills directory |
| **Invocation** | Claude Code reads the local SKILL.md when you type `/pdf` |

---

## How This Scales

In an enterprise environment, the workflow becomes:

1. **Teams author skills** — Each team creates SKILL.md files for their specialized workflows (code review, deployment, compliance checks)
2. **Registry centralizes discovery** — All skills are registered with appropriate visibility (`public`, `group`, `private`)
3. **Developers pull skills** — AI coding assistants download skills from the Registry on demand
4. **Governance is enforced** — The same access control model from Lab 3 applies to skills
5. **Health is monitored** — The Registry tracks whether skill sources are accessible, alerting teams to broken links or deleted files

| Visibility | Who Can See | Use Case |
|-----------|------------|----------|
| `public` | All authenticated users | Shared best practices, standard workflows |
| `group` | Users in the same Keycloak group | Team-specific processes, proprietary methods |
| `private` | Only the registering user | Personal workflows, experimental skills |

:button[Next: View Skill Content]{href="/module-4/step-5-view-skill-content"}
