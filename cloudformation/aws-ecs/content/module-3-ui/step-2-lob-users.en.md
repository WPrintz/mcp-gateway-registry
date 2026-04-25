---
title: "3.2 LOB Users: Restricted Views"
weight: 42
---

Now switch to the line-of-business accounts and see how the same registry looks through a restricted lens. You'll log in as two different LOB users and compare their views against the admin baseline you just recorded.

## LOB 1: Current Time API Team

### Step 1: Login as LOB 1

Open a **new incognito/private browser window** (keep the admin window open for side-by-side comparison):

1. Navigate to your MCP Gateway URL
2. Click **Login** and authenticate with:
   - **Username:** `lob1-user`
   - **Password:** `lob1pass`

:image[LOB 1 dashboard view]{src="/static/img/module-3-ui/3_2/lob1_user_view.png" width=800}

### Step 2: Count the Servers

You should see **2 server cards** — down from 4 as admin:

| Server | Tools | Still visible? |
|--------|-------|----------------|
| **Current Time API** | 1 | ✅ |
| **AI Registry Tools** | 5 | ✅ |
| **Real Server Fake Tools** | 6 | ❌ Gone |
| **Cloudflare Documentation** | 2 | ❌ Gone |

::alert[Both Real Server Fake Tools and Cloudflare Documentation have disappeared entirely. The Registry API filtered them out before the page loaded — this isn't a UI trick. These servers don't appear in API responses for this user either.]{type="info"}

### Step 3: Check the Agents Tab

Switch to the **Agents** tab. You should see **0 agents** — both Flight Booking Agent and Travel Assistant Agent are gone.

:image[LOB 1 agents tab — empty]{src="/static/img/module-3-ui/3_2/lob1_a2a_view.png" width=800}

### Step 4: Record LOB 1 Observations

| Metric | Admin | LOB 1 | Difference |
|--------|-------|-------|------------|
| MCP Servers | 4 | 2 | −2 (Real Server Fake Tools, Cloudflare Documentation) |
| A2A Agents | 2 | 0 | −2 (all agents) |

---

## LOB 2: Real Server Fake Tools Team

### Step 5: Login as LOB 2

Open another **incognito/private browser window**:

1. Navigate to your MCP Gateway URL
2. Click **Login** and authenticate with:
   - **Username:** `lob2-user`
   - **Password:** `lob2pass`

:image[LOB 2 dashboard view]{src="/static/img/module-3-ui/3_2/lob2_user_view.png" width=800}

### Step 6: Count the Servers

You should see **2 server cards** again — but a *different* set:

| Server | Tools | Still visible? |
|--------|-------|----------------|
| **Current Time API** | 1 | ❌ Gone |
| **AI Registry Tools** | 5 | ✅ |
| **Real Server Fake Tools** | 6 | ✅ |
| **Cloudflare Documentation** | 2 | ❌ Gone |

LOB 2 sees Real Server Fake Tools (which LOB 1 couldn't see) but *cannot* see Current Time API (which LOB 1 could). Neither LOB user can see Cloudflare Documentation.

### Step 7: Check the Agents Tab

Switch to the **Agents** tab. Again, **0 agents**.

:image[LOB 2 agents tab — empty]{src="/static/img/module-3-ui/3_2/lob2_a2a_view.png" width=800}

### Step 8: Record LOB 2 Observations

| Metric | Admin | LOB 1 | LOB 2 |
|--------|-------|-------|-------|
| MCP Servers | 4 | 2 | 2 |
| A2A Agents | 2 | 0 | 0 |

---

## Side-by-Side Comparison

Both LOB users see 2 servers and 0 agents, but they see *different* servers:

| Server | Admin | LOB 1 | LOB 2 |
|--------|-------|-------|-------|
| Current Time API | ✅ | ✅ | ❌ |
| AI Registry Tools | ✅ | ✅ | ✅ |
| Real Server Fake Tools | ✅ | ❌ | ✅ |
| Cloudflare Documentation | ✅ | ❌ | ❌ |
| Flight Booking Agent | ✅ | ❌ | ❌ |
| Travel Assistant Agent | ✅ | ❌ | ❌ |

Four things to notice:

1. **AI Registry Tools is shared** — both LOBs can see it. It's the common utility server.
2. **Each LOB has an exclusive server** — LOB 1 gets Current Time API, LOB 2 gets Real Server Fake Tools. Neither can see the other's.
3. **Neither LOB sees agents** — the deployed agents (Flight Booking, Travel Assistant) are only in the admin scope.
4. **Cloudflare Documentation is admin-only** — you registered it in Lab 2, but no LOB scope includes it yet. You'll change that in the next step.

::alert[The tool counts on the server cards (1, 5, 6) are the same for every user who can see that card. The card shows the *total registered tools*, not a per-user filtered count. The difference in what you can actually *invoke* is enforced at a deeper layer — you'll explore that in the next step.]{type="warning"}

## What's Driving This?

Each user's Keycloak group maps to a scope document in DocumentDB. The `ui_permissions.list_service` field in that scope controls which server cards appear:

| User | Keycloak Group | `list_service` value |
|------|---------------|----------------------|
| `admin` | `registry-admins` | `["all"]` |
| `lob1-user` | `registry-users-lob1` | `["currenttime", "airegistry-tools"]` |
| `lob2-user` | `registry-users-lob2` | `["realserverfaketools", "airegistry-tools"]` |

Same registry. Same servers registered. Different views — determined entirely by group membership.

:button[Next: Modify Access Control]{href="/module-3-ui/step-3-iam-modify"}
