---
title: "4.1 Browse the Skills Catalog"
weight: 51
---

Start by exploring what skills are already registered in the MCP Gateway Registry. This step establishes a baseline before you add new skills in later steps.

## Step 1: Navigate to Skills

1. Log in to the Registry UI as `admin`
2. Click the **Skills** section in the left navigation panel

:image[Skills section in the Registry left navigation]{src="/static/img/module-4/4_1/skills-nav-panel.png" width=800}

3. Browse the list of registered skills

The Skills catalog displays each skill as a card, similar to the MCP server cards you saw in Labs 1 and 2. Each card shows the skill name, description, tags, visibility level, and health status.

## Step 2: Search by Tag

Use the search bar to filter skills by tag:

1. Type `pdf` and observe which skills match
2. Clear the search and try `documentation`
3. Try `mcp` to find skills related to MCP server development

:image[Skills catalog filtered by tag]{src="/static/img/module-4/4_1/skills-search-by-tag.png" width=800}

::alert[Skill search works the same way as MCP server search in Lab 2 — keyword filtering happens instantly as you type, matching against skill names, descriptions, and tags.]{type="info"}

## Step 3: View Skill Details

Click on any skill to view its details:

- **Description** — What the skill does
- **Tags** — Categorization for discovery
- **URL** — Source SKILL.md location (the Git repository URL)
- **Visibility** — Who can see this skill (`public`, `group`, or `private`)
- **Health status** — Whether the SKILL.md source is accessible

:image[Skill detail panel showing description, tags, visibility, and health]{src="/static/img/module-4/4_1/skill-detail-panel.png" width=800}

::alert[If the Skills section is empty, that's expected. You'll register skills in the next steps and return here to verify they appear.]{type="info"}

---

## What's Happening Behind the Scenes

The Skills catalog is served by the same Registry API that manages MCP servers. When the UI loads the Skills page, it queries the `mcp_skills` collection in DocumentDB and returns all skills the current user is authorized to see — the same access control model from Lab 3 applies here.

| Component | Role |
|-----------|------|
| **Registry API** | Serves skill metadata from DocumentDB |
| **DocumentDB** | Stores skill registrations in `mcp_skills` collection |
| **UI** | Renders skill cards with search and filtering |

:button[Next: Register an Internal Skill]{href="/module-4/step-2-register-internal-skill"}
