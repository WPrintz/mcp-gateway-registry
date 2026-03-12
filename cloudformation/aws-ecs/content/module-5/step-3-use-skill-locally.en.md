---
title: "5.3 Use Skills in Coding Environment"
weight: 63
---

Download a registered skill from the Registry and use it in Claude Code. This step demonstrates the end-to-end workflow: discover a skill in the Registry, pull it to your local environment, and invoke it in an AI coding assistant.

## Step 1: Download a Skill

Fetch the skill content from the Registry API and save it to the Claude Code skills directory:

:::code{language=bash showCopyAction=true}
mkdir -p ~/.claude/skills/pdf
curl -s -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  "$REGISTRY_URL/api/skills/pdf/content" \
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
315 /home/participant/.claude/skills/pdf/SKILL.md

name: pdf
description: Use this skill whenever the user wants to do anything
  with PDF files...
license: Proprietary. LICENSE.txt has complete terms

# PDF Processing Guide
## Overview
This guide covers essential PDF processing operations using Python
libraries and command-line tools...
:::

The file contains structured instructions that tell the AI assistant how to handle PDF operations — including YAML front matter (name, description, license), an overview, and detailed guidance on using Python libraries and command-line tools.

---

## Step 3: Launch Claude Code

Open Claude Code from your terminal:

:::code{language=bash showCopyAction=true}
claude
:::

You should see the Claude Code welcome screen with the version number and your working directory.

## Step 4: Invoke the Skill

Once Claude Code is running, invoke the skill using its slash command:

:::code{language=text showCopyAction=true}
/pdf
:::

Claude Code loads the SKILL.md instructions from `~/.claude/skills/pdf/SKILL.md` and applies them to your conversation. You should see the skill content injected into the prompt context.

:image[Claude Code with the pdf skill invoked]{src="/static/img/module-5/5_3/claude-code-skill-invoked.png" width=800}

Try asking Claude Code to do something PDF-related, for example: "Create a simple PDF with a title and some sample text."

Claude Code will generate a Python script, install any needed dependencies, and run it. You will be prompted to approve several actions (file writes, shell commands). For each prompt, select **Yes** or choose **Yes, allow all edits during this session (shift+tab)** to approve all remaining prompts automatically.

:image[Claude Code confirmation prompts during PDF creation]{src="/static/img/module-5/5_3/claude-code-confirmations.png" width=800}

Once complete, Claude Code will confirm the PDF was created successfully.

::alert[Skills are behavioral guidance, not executable tools. When you invoke `/pdf`, the assistant doesn't call an API — it reads the instructions and applies them to your request. This is fundamentally different from MCP tools (Lab 2), which execute functions and return results.]{type="info"}

## Step 5: View the Generated PDF

In the Code Editor, look at the file explorer on the left sidebar — you should see the generated PDF file (e.g., `sample_document.pdf`). Right-click the file and select **Download** to save it to your local machine, then open it in a PDF viewer.

:image[Generated PDF document created by Claude Code using the pdf skill]{src="/static/img/module-5/5_3/pdf-generated.png" width=800}

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

:button[Next: View Skill Content]{href="/module-5/step-4-view-skill-content"}
