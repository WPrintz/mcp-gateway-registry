---
title: "5.3 Use Skills in Coding Environment"
weight: 63
---

You've registered skills and verified they're healthy. Now pull one down and use it.

## Step 1: Download a Skill

Fetch the skill content from the Registry API and save it to the Claude Code skills directory:

:::code{language=bash showCopyAction=true}
mkdir -p ~/.claude/skills/pdf
curl -s -H "Authorization: Bearer $(jq -r '.tokens.access_token // .access_token' .token)" \
  "$REGISTRY_URL/api/skills/pdf/content" \
  | jq -r '.content' > ~/.claude/skills/pdf/SKILL.md
:::


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

The file contains YAML front matter and detailed instructions for PDF operations.

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

Claude Code generates a Python script, installs dependencies, and runs it. It prompts you to approve each action (file writes, shell commands) — select **Yes** or **Yes, allow all edits during this session (shift+tab)** to approve all at once.

:image[Claude Code confirmation prompts during PDF creation]{src="/static/img/module-5/5_3/claude-code-confirmations.png" width=800}

Claude Code confirms the PDF was created.

::alert[When you invoke `/pdf`, the assistant reads the instructions and applies them to your request — it doesn't call an API. This is different from MCP tools (Lab 2), which execute functions and return results.]{type="info"}

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

:button[Next: View Skill Content]{href="/module-5/step-4-view-skill-content"}
