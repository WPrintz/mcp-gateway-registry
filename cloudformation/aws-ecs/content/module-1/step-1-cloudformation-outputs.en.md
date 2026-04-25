---
title: "1.1 Find CloudFormation Outputs"
weight: 21
---

The workshop infrastructure is deployed via CloudFormation. All the URLs and credentials you need are available in the stack outputs.

## Step 1: Open the CloudFormation Console

1. In the AWS Console, navigate to **CloudFormation** (search for "CloudFormation" in the search bar)


:image[Search for CloudFormation in AWS Console]{src="/static/img/module-1/1_1/Cfn_start.png" width=800}

::alert[If you don't see any stacks, check that you're viewing the correct region in which your workshop was launched using the region selector in the top-right corner.]{type="warning"}

## Step 2: Find the Main Stack

1. Look for a stack named **main-stack**
1. Click on the stack name to open the stack details

:image[CloudFormation Stack List]{src="/static/img/module-1/1_1/Cfn_main_stack.png" width=800}

## Step 3: View the Outputs Tab

1. Click the **Outputs** tab
1. You'll see the key URLs and resource information:

:image[CloudFormation Outputs Tab]{src="/static/img/module-1/1_1/Cfn_outputs_passwd.png" width=800}

| Output Key | Description | Example Value |
|---|---|---|
| **MCPGatewayUrl** | Main Registry UI URL (HTTPS via CloudFront) | `https://dxxxxxxxxxx.cloudfront.net` |
| **KeycloakUrl** | Keycloak Admin Console URL (HTTPS via CloudFront) | `https://dxxxxxxxxxx.cloudfront.net` |
| **GrafanaUrl** | Grafana Dashboard URL (anonymous access enabled) | `https://dxxxxxxxxxx.cloudfront.net/grafana/` |
| **CodeEditorUrl** | Code Editor IDE URL (CloudFront HTTPS with auto-login token) | `https://dxxxxxxxxxx.cloudfront.net/?folder=/workshop&tkn=...` |
| **CodeEditorPassword** | Link to Secrets Manager for IDE password | Console URL |
| **MCPGatewayAdminPassword** | Link to Secrets Manager for admin password | Console URL |
| **KeycloakAdminPassword** | Link to SSM Parameter Store for Keycloak admin password | Console URL |
| **UpstreamVersion** | MCP Gateway Registry version deployed | `v1.0.16` |

::alert[**Save these URLs!** You'll use the MCPGatewayUrl throughout the workshop. Consider copying them to a text file or keeping this tab open.]{type="info" header="Pro Tip"}

## Step 4: Retrieve the Admin Password

1. Click the **MCPGatewayAdminPassword** output value (it's a link to Secrets Manager)
1. In Secrets Manager, click **Retrieve secret value**
1. Copy the password - you'll need this to log in

:image[Secrets Manager - Retrieve Secret Value]{src="/static/img/module-1/1_1/Secrets_Manager_retrieve_secret.png" width=800}

Alternatively, you can retrieve the password using **AWS CloudShell** — a browser-based terminal built into the AWS Console. CloudShell comes pre-installed with the AWS CLI and is automatically authenticated with your current session, so there's nothing to install or configure.

### Opening CloudShell

You can open CloudShell directly from the same CloudFormation console page you're on:

1. Click the **CloudShell icon** in the bottom toolbar of the AWS Console (or use the search bar to search for "CloudShell")
2. Wait a few seconds for the environment to initialize — you'll see a terminal prompt

:image[Opening CloudShell from the AWS Console toolbar]{src="/static/img/module-1/1_1/CloudShell_open.png" width=800}

::alert[CloudShell sessions persist for a limited time. If your session expires, simply reopen it — your files in the home directory are preserved. You'll need to re-export the `$AWS_REGION` variable when starting a new session.]{type="info"}

### Set Your Region

First, set the workshop region — this variable is used by all CLI commands throughout the workshop:

:::code{language=bash showCopyAction=true}
# Set the workshop region (used by all CLI commands in this workshop)
export AWS_REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text)
echo "Workshop region: $AWS_REGION"
:::

::alert[This command auto-detects the region your CloudShell is running in. All CLI commands in this workshop use `$AWS_REGION` so they work regardless of which region the workshop was launched in. If you open a new terminal session, re-run this export command.]{type="info"}

### Retrieve the Password

:::code{language=bash showCopyAction=true}
# Get the admin password from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id mcp-gateway-admin-password \
  --query 'SecretString' \
  --output text \
  --region $AWS_REGION
:::

:image[Retrieving the admin password in CloudShell]{src="/static/img/module-1/1_1/CloudShell_retrieve_secret.png" width=800}

::alert[**You'll use CloudShell again** in Labs 2, 3, and 4 for CLI-based testing and API calls. Keep this tab open or remember how to access it from the console toolbar.]{type="info" header="CloudShell in Later Labs"}

## Validation

You should now have:

- The **MCPGatewayUrl** (CloudFront HTTPS URL for the Registry UI)
- The **KeycloakUrl** (CloudFront HTTPS URL for Keycloak admin)
- The **admin password** from Secrets Manager
