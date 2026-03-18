---
title: "4.1 Launch the Cloud IDE"
weight: 51
---

Your workshop environment includes a browser-based Code Editor with Claude Code and Kiro CLI already installed. Let's make sure everything is working.

## Step 1: Open the Code Editor

1. Go to the **CloudFormation Outputs** tab (Lab 1)
2. Click the **CodeEditorUrl** value — this opens the Code Editor in a new browser tab

The URL includes an auto-login token, so you should land directly in the VS Code interface with a terminal available.

:image[Code Editor landing page with terminal]{src="/static/img/module-4/4_1/code-editor-landing.png" width=800}

::alert[If the Code Editor shows a login prompt instead of auto-logging in, copy the full URL from CloudFormation outputs again — the `tkn` parameter handles authentication.]{type="warning"}

## Step 2: Open a Terminal

If a terminal is not already visible:

1. Click **Terminal** in the top menu bar
2. Select **New Terminal**

You should see a bash prompt as the `participant` user.

## Step 3: Verify Claude Code

Run the following command to confirm Claude Code is installed:

:::code{language=bash showCopyAction=true}
claude --version
:::

You should see output like:

:::code{language=text showCopyAction=false}
2.1.x (Claude Code)
:::

Claude Code is pre-configured to use **Amazon Bedrock** as its LLM backend. The instance role provides IAM-based access to Bedrock Claude models — no API key is needed.

Verify the Bedrock configuration:

:::code{language=bash showCopyAction=true}
echo "CLAUDE_CODE_USE_BEDROCK=$CLAUDE_CODE_USE_BEDROCK"
echo "ANTHROPIC_MODEL=$ANTHROPIC_MODEL"
echo "AWS_REGION=$AWS_REGION"
:::

You should see:

:::code{language=text showCopyAction=false}
CLAUDE_CODE_USE_BEDROCK=1
ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-5-20250929-v1:0
AWS_REGION=<your-deployed-region>
:::

::alert[Claude Code connects to Amazon Bedrock using the EC2 instance role. No Anthropic API keys are stored or needed.]{type="info"}

## Step 4: Verify Kiro CLI

Check that Kiro CLI is installed:

:::code{language=bash showCopyAction=true}
kiro-cli --version
:::

You should see output like:

:::code{language=text showCopyAction=false}
kiro-cli 1.27.x
:::

## Step 5: Authenticate Kiro CLI

Kiro CLI requires a one-time authentication with **AWS Builder ID**. The Code Editor is headless (no browser), so use the device flow:

1. Run the following command:

:::code{language=bash showCopyAction=true}
kiro-cli login --use-device-flow
:::

2. When prompted for login method, select **Use for Free with Builder ID**
3. Kiro CLI displays a code and a URL. Open the URL in your local browser (not the Code Editor) and enter the code.
   - If you don't have an AWS Builder ID, create a free account at the sign-up page (takes about 2 minutes)
4. After authentication completes, verify by launching a chat session:

:::code{language=bash showCopyAction=true}
kiro-cli chat
:::

5. It should start without a login prompt. Type `/exit` to return to the terminal.

::alert[AWS Builder ID is a free personal account separate from your AWS Console credentials. It's used for developer tools like Kiro CLI and Amazon CodeWhisperer.]{type="info"}

::alert[If the terminal appears stuck after completing browser authentication, press `Ctrl+C` and re-run `kiro-cli login --use-device-flow`. This can happen if the browser step takes too long (password reset, account creation). The second attempt usually completes immediately.]{type="warning"}

## Step 6: Verify the Registry URL

The MCP Gateway URL is pre-configured as an environment variable:

:::code{language=bash showCopyAction=true}
echo "MCP_GATEWAY_URL=$MCP_GATEWAY_URL"
:::

You should see the CloudFront HTTPS URL for your MCP Gateway Registry.

---

## Validation

You should now have:

- The Code Editor open in your browser with a working terminal
- Claude Code installed and configured for Bedrock
- Kiro CLI installed and authenticated with AWS Builder ID
- The `MCP_GATEWAY_URL` environment variable set

:button[Next: Direct Connection]{href="/module-4/step-2-direct-connection"}
