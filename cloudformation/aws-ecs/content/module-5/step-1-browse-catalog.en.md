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

Each card shows the skill name with an orange `SKILL` badge, a visibility badge (`PUBLIC` in this case), the description, tags, and a health indicator in the footer. The ℹ️ icon on the top-right opens the full SKILL.md content in a modal where you can read, copy, or download it.

## Step 2: View the SKILL.md Content

Click the **ℹ️ info icon** (top-right of the card) on **frontend-design** to open the detail modal:

:image[Skill detail modal showing rendered SKILL.md content for frontend-design]{src="/static/img/module-5/5_1/skill-detail-panel.png" width=800}

The modal displays the full rendered SKILL.md content — the same instructions an AI coding assistant reads when the skill is invoked. Close the modal and click the ℹ️ icon on **canvas-design** to compare. Notice they have different instructions tailored to their domain, but the same card structure and metadata fields.

## Step 3: Record Your Baseline

Take note of the current state — you'll compare it after registering new skills:

| Metric | Current Count |
|--------|---------------|
| Registered Skills | 2 |
| Public Skills | 2 |
| Group Skills | 0 |
| Healthy Skills | 2 |

---

## What's Happening Behind the Scenes

The Skills catalog is served by the same Registry API that manages MCP servers. When the UI loads the Skills page, it queries the `mcp_skills` collection in DocumentDB and returns all skills the current user is authorized to see — the same access control model from Lab 3 applies here.

The two pre-registered skills were created during deployment by a CloudFormation Custom Resource Lambda — the same Lambda that registered the pre-deployed MCP servers and A2A agents in Labs 1-3.

| Component | Role |
|-----------|------|
| **CloudFormation Lambda** | Auto-registered the 2 skills during deployment |
| **Registry API** | Serves skill metadata from DocumentDB |
| **DocumentDB** | Stores skill registrations in `mcp_skills` collection |
| **UI** | Renders skill cards with search and filtering |

:button[Next: Register Skills]{href="/module-5/step-2-register-skills"}
