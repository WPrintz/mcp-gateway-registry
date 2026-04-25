---
title: "1.2 Access the Registry UI"
weight: 22
---

Now that you have the URLs, let's access the Registry UI and authenticate.

## Step 1: Open the Registry URL

1. Open a new browser tab
1. Navigate to your **MCPGatewayUrl** from the CloudFormation outputs
   - Example: `https://d1234abcd.cloudfront.net`

::alert[Use the CloudFront URL (starts with `https://`). This provides HTTPS encryption necessary for KeyCloak .  For production use cases, the open-source deployment provides options for CloudFront as well as custom DNS ingress URLs.]{type="info"}

## Step 2: Initiate Login

1. You'll see the MCP Gateway Registry landing page
1. On the login page, click the **Continue with Keycloak** button

:image[Registry Landing Page]{src="/static/img/module-1/1_2/Registry_login_page.png" width=400}

## Step 3: Authenticate with Keycloak

You'll be redirected to the Keycloak login form. The workshop provides pre-configured user accounts:

| Username | Password | Role | Access Level |
|---|---|---|---|
| `admin` | (from Secrets Manager) | Platform Admin | Full access to all servers and agents |
| `testuser` | `testpass` | Developer/Operator | All servers and agents (read/execute) |
| `lob1-user` | `lob1pass` | LOB 1 User | Current Time API + AI Registry Tools only |
| `lob2-user` | `lob2pass` | LOB 2 User | Real Server Fake Tools + AI Registry Tools only |

1. Enter the **admin** username
1. Enter the password you retrieved from Secrets Manager
1. Click **Sign In**

:image[Keycloak Login]{src="/static/img/module-1/1_2/Registry_keycloak_login.png" width=400}

::alert[CloudFront provides valid HTTPS certificates, so you should not see a certificate warning. If you do, verify you're using the correct URL from the CloudFormation outputs.]{type="info"}

## Step 4: Verify Successful Login

After successful authentication, you'll be redirected back to the Registry UI. You should see:

- Your username displayed in the top-right corner
- The main dashboard with MCP servers and agents
- Navigation options for Servers, Agents, Skills, and Search

:image[Successful Login - Dashboard View]{src="/static/img/module-1/1_2/Registry_first_login.png" width=800}

::alert[**Congratulations!** You're now authenticated and ready to explore the MCP Gateway Registry.]{type="success" header="Login Successful"}

## Understanding the Authentication Flow

What just happened behind the scenes:

1. **OAuth2 Authorization Code Flow**: The Registry redirected you to Keycloak
1. **User Authentication**: Keycloak verified your credentials
1. **Token Issuance**: Keycloak issued a JWT token with your identity and group memberships
1. **Session Cookie**: The Registry stored a secure session cookie for subsequent requests

This same flow is used by AI agents, but they use **Machine-to-Machine (M2M)** authentication with client credentials instead of interactive login.

## Troubleshooting

::::expand{header="Login redirects to an error page"}
- Verify you're using the correct CloudFront URL from CloudFormation outputs
- Check that Keycloak is healthy (visit the KeycloakUrl directly)
- Clear browser cookies and try again
::::

::::expand{header="Invalid username or password"}
- For `admin`: Retrieve the password from Secrets Manager (it's auto-generated)
- For `testuser`: Password is `testpass`
- For `lob1-user`: Password is `lob1pass`
- For `lob2-user`: Password is `lob2pass`
- Passwords are case-sensitive
::::

::::expand{header="Page loads but shows 'Unauthorized'"}
- Your session may have expired - click Login again
- Verify your user is assigned to the correct Keycloak groups
::::
