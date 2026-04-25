---
title: "3.4 Create Groups, Users, and M2M Accounts"
weight: 44
---

In the previous step, you modified existing groups and users. Now you'll use the IAM Settings panel to create entirely new ones — the full CRUD lifecycle through the UI. This is the strongest differentiator from the terminal-based workflow: creating a complete access control pipeline without writing a single JSON file or API call.

## Scenario

A new **Data Engineering** team needs access to the Cloudflare Documentation server. The team requires:
- A dedicated group with access to only the Cloudflare Documentation server (both tools)
- A human user account for the team lead
- An M2M service account for their automation pipeline

You'll create all three through the IAM Settings panel, verify they work, and then clean up.

---

## Step 1: Create the Group

1. Log in as `admin`
2. Navigate to **Settings** > **IAM** > **Groups**
3. Click **Create** (or **"+ New Group"**)
4. Fill in the group form:

| Field | Value |
|-------|-------|
| **Group Name** | `data-engineering` |
| **Description** | `Data Engineering team — Cloudflare Documentation access` |
| **Create in IdP** | ✅ Checked |

5. In the **Server Access** section, click **"+ Add Server"** and configure:

| Field | Value |
|-------|-------|
| Server | `cloudflare-docs` |
| Methods | `initialize`, `notifications/initialized`, `ping`, `tools/list`, `tools/call` |
| Tools | `*` (all) |

6. Review the **JSON Preview** panel on the right — verify that `cloudflare-docs` appears in both `server_access` and in `ui_permissions` (the UI permissions are auto-synced from your server access entries):

:image[Create group form with server access and JSON preview]{src="/static/img/module-3-ui/3_4/iam_groups_create_server_access.png" width=800}

:image[JSON Preview for data-engineering group]{src="/static/img/module-3-ui/3_4/iam_groups_create_json_preview.png" width=800}

7. Click **Create Group**

::alert[With **Create in IdP** checked, the group is created in both DocumentDB (scope definition) and Keycloak (identity group) simultaneously. If you uncheck it, only the DocumentDB scope is created — useful when the Keycloak group already exists.]{type="info" header="IdP Sync"}

---

## Step 2: Create the User

1. Navigate to **Settings** > **IAM** > **Users**
2. Click **Create** (or **"+ New User"**)
3. Fill in the user form:

| Field | Value |
|-------|-------|
| **Username** | `data-eng-user` |
| **Email** | `data-eng@example.com` |
| **First Name** | `Data` |
| **Last Name** | `Engineer` |
| **Password** | `datapass` |
| **Groups** | Select `data-engineering` |

:image[Create user form with group selection]{src="/static/img/module-3-ui/3_4/iam_users_create.png" width=800}

4. Click **Create User**

The user is created in Keycloak and assigned to the `data-engineering` group. Their permissions are determined by the scope you defined in Step 1.

---

## Step 3: Verify the New User

1. Open a **new incognito/private browser window**
2. Navigate to your MCP Gateway URL
3. Click **Login** and authenticate with:
   - **Username:** `data-eng-user`
   - **Password:** `datapass`

You should see **1 server card** — Cloudflare Documentation:

:image[data-eng-user dashboard showing 1 server]{src="/static/img/module-3-ui/3_4/new_user_dashboard.png" width=800}

| Server | Visible? |
|--------|----------|
| Current Time API | ❌ |
| AI Registry Tools | ❌ |
| Real Server Fake Tools | ❌ |
| Cloudflare Documentation | ✅ |

This confirms the full pipeline is working:
1. **Keycloak** — `data-eng-user` is a member of `data-engineering` group
2. **DocumentDB** — the `data-engineering` scope grants access to `cloudflare-docs` only
3. **Registry API** — filters the server list to show only Cloudflare Documentation

::alert[Unlike the LOB users who have `tools: ["search_cloudflare_documentation"]` (1 tool), this group has `tools: ["*"]` (all tools). The `data-eng-user` can invoke **both** `search_cloudflare_documentation` and `migrate_pages_to_workers_guide`.]{type="info"}

---

## Step 4: Create an M2M Service Account (Optional)

Machine-to-machine (M2M) accounts allow AI agents and automation pipelines to authenticate without a browser.

1. Navigate to **Settings** > **IAM** > **M2M**
2. Click **Create** (or **"+ New M2M Account"**)
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Account Name** | `data-eng-bot` |
| **Description** | `Data Engineering automation pipeline` |
| **Groups** | Select `data-engineering` |

:image[Create M2M account form]{src="/static/img/module-3-ui/3_4/iam_m2m_create.png" width=800}

4. Click **Create Account**

After creation, you'll see a **one-time credentials display** showing the `client_id` and `client_secret`:

:image[One-time credentials display for data-eng-bot]{src="/static/img/module-3-ui/3_4/iam_m2m_credentials.png" width=800}

::alert[**Save these credentials immediately.** The client secret is displayed only once and cannot be retrieved later. Copy both the `client_id` and `client_secret` to a secure location. If you lose the secret, you'll need to delete and recreate the M2M account.]{type="warning" header="One-Time Secret"}

The M2M account `data-eng-bot` has the same permissions as `data-eng-user` — it belongs to the same `data-engineering` group and gets the same scope. The only difference is the authentication method (Client Credentials instead of browser login).

---

## Step 5: Clean Up

To leave the environment in its original state for subsequent modules, delete the resources you created — in reverse order.

### Delete the M2M Account (if created)

1. Navigate to **Settings** > **IAM** > **M2M**
2. Find `data-eng-bot` in the table
3. Click the **delete icon** and confirm

### Delete the User

1. Navigate to **Settings** > **IAM** > **Users**
2. Find `data-eng-user` in the table
3. Click the **delete icon** and confirm

### Delete the Group

1. Navigate to **Settings** > **IAM** > **Groups**
2. Find `data-engineering` in the table
3. Click the **delete icon** and confirm

::alert[Deletion is immediate. Once you delete the group, any remaining users or M2M accounts in that group lose their scope-based permissions instantly. Always delete users and M2M accounts first, then the group.]{type="info"}

---

## Lab 3 Summary

| Step | What You Learned |
|------|------------------|
| **3.1** | Admin sees all 4 servers, 2 agents, 14 total tools — the full platform view |
| **3.2** | LOB users see only their assigned servers, no agents — same registry, different views |
| **3.3** | You can modify access by changing group membership (IAM > Users) or by updating scope definitions (IAM > Groups) — all through the UI |
| **3.4** | You can create new groups, users, and M2M accounts through the IAM Settings panel — the full CRUD lifecycle without any terminal commands |
| **3.5** *(optional)* | The same operations can be performed via the Registry API — useful for automation, infrastructure-as-code, and debugging |

### Key Takeaways

- **Group membership drives scope selection** — Keycloak groups map to DocumentDB scope documents
- **Scope documents define all three layers** — UI visibility, method access, and tool-level invocation permissions in a single JSON document
- **Changes are dynamic** — no code changes or redeployment needed. Group membership changes take effect on next login; scope document changes take effect immediately
- **Tool-level control is granular** — you can allow a user to see a server and list its tools, but restrict which specific tools they can invoke
- **The same model applies to M2M service accounts** — `data-eng-bot` gets the same scopes as `data-eng-user`
- **The IAM Settings panel provides full CRUD** — create, read, update, and delete groups, users, and M2M accounts without leaving the browser
- **You governed the server you registered** — the Cloudflare Documentation server from Lab 2 is now accessible to LOB1 (1 tool) and was accessible to your new Data Engineering group (all tools)

::alert[**Lab 3 Complete!** You've experienced and modified fine-grained access control at every layer of the MCP Gateway — and created a complete access pipeline from scratch using only the UI. In Lab 4, you'll integrate an AI coding assistant with the MCP Gateway to put all of this to practical use. **Optional:** Continue to [Step 3.5](/module-3-ui/step-5-api-access-control) to perform the same operations via API.]{type="success" header="Well Done!"}

