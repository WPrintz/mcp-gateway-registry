---
title: "5.1 Browse the Skills Catalog"
weight: 61
---

Start by exploring the skills that are already registered in the MCP Gateway Registry. The workshop environment comes pre-configured with two skills from Anthropic's public skills repository — just like the pre-deployed MCP servers you explored in Lab 1.

## Pre-Registered Skills

The workshop deployment automatically registers these skills:

| Skill | Description | Tags | Source |
|-------|-------------|------|--------|
| **frontend-design** | Create distinctive, production-grade frontend interfaces with high design quality | `design`, `frontend`, `ui` | `anthropics/skills` repo |
| **canvas-design** | Create beautiful visual art in .png and .pdf documents using design philosophy | `design`, `canvas`, `art` | `anthropics/skills` repo |

By the end of this lab, you'll add 3 more skills — growing the catalog from 2 to 5.

---

## Step 1: Navigate to Skills

1. Log in to the Registry UI as `admin`
2. Click the **Skills** section in the left navigation panel
3. You should see **2 skill cards** — `frontend-design` and `canvas-design`

:image[Skills catalog showing the two pre-registered skills]{src="/static/img/module-5/5_1/skills-nav-panel.png" width=800}

The ℹ️ icon on each card opens the full SKILL.md content in a modal.

## Step 2: View the SKILL.md Content

Click the **ℹ️ info icon** (top-right of the card) on **frontend-design** to open the detail modal:

:image[Skill detail modal showing rendered SKILL.md content for frontend-design]{src="/static/img/module-5/5_1/skill-detail-panel.png" width=800}

The modal displays the full rendered SKILL.md content — the same instructions an AI coding assistant reads when the skill is invoked. Close the modal and click the ℹ️ icon on **canvas-design** to compare. Notice they have different instructions tailored to their domain, but the same card structure and metadata fields.

:button[Next: Register Skills]{href="/module-5/step-2-register-skills"}
