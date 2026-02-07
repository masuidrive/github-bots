# Claude Code Bot - GitHub Actions Integration

Complete implementation guide for running Claude Code Bot in GitHub Actions with devcontainer.

Always respond in the language used by the user in their request or in previous conversations.

This document is a setup guide. You (the AI assistant reading this) will execute the setup steps to install Coding Robot into the user's repository. You are the **setup executor** — a different role from the Coding Robot itself, which runs later in GitHub Actions using `system.md` as its instructions.

---

## Setup Execution

Follow the steps below to complete the setup:

### Step 1: Create a Task List — Do This Before Any Other Work

Before executing any setup step, you must first use your task management tool to create a task list containing all steps below. Do not check prerequisites, do not download files, do not run any commands until the task list exists.

The reason is that this setup has 9 interdependent steps. Without a task list to track progress, steps get skipped and setup fails silently. The task list is your single source of truth throughout this process.

**How to create the task list (by AI assistant type):**
- Claude Code: Call `TaskCreate` for each step with an `activeForm` parameter
- GitHub Copilot: Create a checklist in a comment or markdown block
- Cursor/Other AI: Maintain a written checklist in your response

**Create one task for each of these steps:**
1. Create task list (this step)
2. Prerequisites check (gh CLI, authentication, token setup)
3. Check existing files
4. Update existing setup (if applicable)
5. Download configuration files (for new setup)
6. Verify CLAUDE_CODE_OAUTH_TOKEN secret
7. Commit and push changes
8. Verify workflow file
9. Run automated verification — with `gh`: create issue, wait for bot response, check logs if error; without `gh`: guide user to create issue manually

**After creating all tasks:** Mark Step 1 as completed, then mark Step 2 as `in_progress` and begin working on it. Continue this pattern for every subsequent step — mark `in_progress` when starting, `completed` when done.

### Step 2: Prerequisites Check

**IMPORTANT: Check required tools and authentication before proceeding.**

**⚡ Performance Tip:** Combine commands with `&&` to execute them together in a single bash call instead of running them one by one. This reduces the number of permission prompts for the user.

**Example:**
```bash
# Good - Execute all checks together
command -v gh && gh auth status && git remote get-url origin

# Bad - Execute one by one (causes multiple permission prompts)
command -v gh
gh auth status
git remote get-url origin
```

**Combined Prerequisites Check Script (Recommended):**

Execute all checks together in a single command to minimize permission prompts:

```bash
# Combined prerequisites check
echo "🔍 Checking prerequisites..."
GH_AVAILABLE=false

# 1. Check gh CLI (optional but recommended)
if command -v gh &> /dev/null; then
  echo "✅ GitHub CLI (gh) is installed: $(gh --version | head -1)"
  # 2. Check GitHub authentication
  if gh auth status &> /dev/null; then
    echo "✅ GitHub authentication verified"
    GH_AVAILABLE=true
  else
    echo "⚠️  gh is installed but not authenticated. Run: gh auth login"
  fi
else
  echo "⚠️  GitHub CLI (gh) is not installed (optional)"
  echo "   Without gh: token setup and automated verification will be skipped"
  echo "   Install from: https://cli.github.com/"
fi

# 3. Verify repository
REPO_URL=$(git remote get-url origin 2>/dev/null)
if [ -z "$REPO_URL" ]; then
  echo "❌ No git remote 'origin' found"
  echo "Please initialize a git repository and set the remote"
  exit 1
fi
REPO_NAME=$(echo "$REPO_URL" | sed -E 's#.*[:/]([^/]+/[^/]+)\.git#\1#' | sed 's/\.git$//')
echo "✅ Repository detected: $REPO_NAME"

echo ""
if [ "$GH_AVAILABLE" = true ]; then
  echo "✅ All prerequisites check passed! (gh available - full setup)"
else
  echo "⚠️  Prerequisites check done (gh not available - limited setup)"
  echo "   Steps 6 (token setup) and 9 (automated verification) will be adjusted"
fi
```

**How `gh` availability affects subsequent steps:**

| Step | With `gh` | Without `gh` |
|------|-----------|--------------|
| Step 6: Token setup | Set `CLAUDE_CODE_OAUTH_TOKEN` via `gh secret set` | **Skip** - user sets it manually in GitHub Settings |
| Step 9: Verification | Automated: create issue, poll for response, check logs | **Manual**: user creates issue from browser, `run-action.sh` will report errors (including missing token) in the issue comment |

<details>
<summary>Individual checks (click to expand if you need step-by-step)</summary>

#### 1. Check GitHub CLI (`gh`) installation

```bash
# Check if gh command is available
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI (gh) is not installed"
  echo "Please install it from: https://cli.github.com/"
  exit 1
fi

echo "✅ GitHub CLI (gh) is installed: $(gh --version | head -1)"
```

#### 2. Check GitHub authentication status

```bash
# Check if user is logged in to GitHub
if ! gh auth status &> /dev/null; then
  echo "❌ Not logged in to GitHub"
  echo "Please run: gh auth login"
  exit 1
fi

echo "✅ GitHub authentication verified"
gh auth status
```

#### 3. Verify repository information

```bash
# Get current repository from git remote
REPO_URL=$(git remote get-url origin 2>/dev/null)
if [ -z "$REPO_URL" ]; then
  echo "❌ No git remote 'origin' found"
  echo "Please initialize a git repository and set the remote"
  exit 1
fi

# Extract repository name (owner/repo format)
REPO_NAME=$(echo "$REPO_URL" | sed -E 's#.*[:/]([^/]+/[^/]+)\.git#\1#' | sed 's/\.git$//')
echo "✅ Repository detected: $REPO_NAME"
```

</details>

#### 4. Check and setup CLAUDE_CODE_OAUTH_TOKEN

**⚠️ CRITICAL: AI assistants CANNOT run `claude setup-token` automatically.**

This command requires interactive authentication in a browser and MUST be executed by the user in a separate terminal window. The AI assistant should:
- Check if the token is already set
- Explain how to run `claude setup-token`
- **DO NOT use interactive selection tools (AskUserQuestion, etc.)**
- Simply wait for the user to paste the token

```bash
# Check if CLAUDE_CODE_OAUTH_TOKEN secret exists
SECRET_EXISTS=$(gh api repos/$REPO_NAME/actions/secrets 2>/dev/null | jq -r '.secrets[] | select(.name=="CLAUDE_CODE_OAUTH_TOKEN") | .name' || echo "")

if [ -n "$SECRET_EXISTS" ]; then
  echo "✅ CLAUDE_CODE_OAUTH_TOKEN secret is already set"
else
  echo "⚠️  CLAUDE_CODE_OAUTH_TOKEN secret is NOT set"
  echo ""
  echo "This token is required for Claude Bot to authenticate with Claude API."
  echo ""
  echo "⚠️  IMPORTANT: AI assistants CANNOT run 'claude setup-token' for you."
  echo "This command requires interactive authentication and must be run by YOU."
  echo ""
  echo "To obtain the token:"
  echo "  1. Open a NEW terminal window/tab (SEPARATE from this AI session)"
  echo "  2. Run: claude setup-token"
  echo "  3. Follow the interactive prompts to authenticate"
  echo "  4. Copy the token value displayed"
  echo "  5. Return here and paste the token when prompted"
  echo ""

  # Wait for user to paste the token
  echo "Please paste your CLAUDE_CODE_OAUTH_TOKEN:"
  read -s CLAUDE_TOKEN

  if [ -n "$CLAUDE_TOKEN" ]; then
    # Set the GitHub secret
    gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "$CLAUDE_TOKEN" --repo "$REPO_NAME"

    if [ $? -eq 0 ]; then
      echo "✅ CLAUDE_CODE_OAUTH_TOKEN secret has been set successfully"
    else
      echo "❌ Failed to set CLAUDE_CODE_OAUTH_TOKEN secret"
      echo "You can set it manually at:"
      echo "https://github.com/$REPO_NAME/settings/secrets/actions"
      exit 1
    fi
  else
    echo "⚠️  No token provided. You'll need to set it manually:"
    echo "https://github.com/$REPO_NAME/settings/secrets/actions"
    echo ""
    echo "Setup will continue, but the bot won't work until the token is set."
  fi
fi
```

**Note:** The above script shows the concept. When implementing, the AI assistant should:
1. Explain how to run `claude setup-token` in a separate terminal
2. Display the instructions clearly
3. **DO NOT present multiple choice options or use selection tools**
4. Simply wait for the user to paste the token
5. Set the GitHub secret once the token is provided

### Step 3: Check Existing Files

Before downloading, check for existing files:

```bash
# Check for existing Claude Bot setup
if [ -f ".github/workflows/coding-robot.yml" ]; then
  echo "⚠️  Existing Claude Bot setup found"
  EXISTING_CLAUDE_BOT=true
else
  EXISTING_CLAUDE_BOT=false
fi

# Check for existing devcontainer
if [ -d ".devcontainer" ]; then
  echo "⚠️  Existing .devcontainer found"
  EXISTING_DEVCONTAINER=true
else
  EXISTING_DEVCONTAINER=false
fi

# Check for existing .github/coding-robot directory
if [ -d ".github/coding-robot" ]; then
  echo "⚠️  .github/coding-robot directory already exists"
fi
```

### Step 4: Update Existing Setup (If Applicable)

**If `.github/workflows/coding-robot.yml` already exists (EXISTING_CLAUDE_BOT=true):**

This is an **update operation**, not a fresh installation. Follow these steps:

```bash
echo "📦 Updating existing Claude Bot setup to latest version..."

# Create .github directories if needed
mkdir -p .github/workflows .github/coding-robot

# Download and update ONLY these files:
curl -o .github/workflows/coding-robot.yml https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml
curl -o .github/coding-robot/run-action.sh https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh
curl -o .github/coding-robot/system.md https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system.md

# Make script executable
chmod +x .github/coding-robot/run-action.sh

echo "✅ Updated coding-robot.yml, run-action.sh, and system.md to latest versions"
```

**DO NOT update these files (preserve existing configuration):**
- ❌ `.devcontainer/devcontainer.json` - Keep existing devcontainer setup
- ❌ `.devcontainer/Dockerfile` - Keep existing Docker configuration
- ❌ `.claude/CLAUDE.md` - Keep project-specific test instructions

**After updating, skip to Step 6** (verify secret) and then Step 7 (commit and push).

### Step 5: Download Configuration Files (For New Setup)

**Only execute this step if EXISTING_CLAUDE_BOT=false (no existing Claude Bot setup).**

Based on existing files:

**If NO existing .devcontainer:**
- Download all files from this gist (see File Structure below)
- Create directories: `.github/workflows`, `.github/coding-robot`, `.devcontainer`
- Download using curl commands provided in File Structure section

**If existing .devcontainer found:**
- **DO NOT download .devcontainer files**
- Instead, follow "Adapting to Existing Devcontainer" section
- Add required commands and Claude CLI to existing setup
- Only download `.github/workflows/coding-robot.yml`, `.github/coding-robot/run-action.sh`, and `.github/coding-robot/system.md`

**Files to download for new setup:**
- `.github/workflows/coding-robot.yml`
- `.github/coding-robot/run-action.sh` (and make executable)
- `.github/coding-robot/system.md`
- `.devcontainer/devcontainer.json` (if no existing devcontainer)
- `.devcontainer/Dockerfile` (if no existing devcontainer)

### Step 6: Verify CLAUDE_CODE_OAUTH_TOKEN Secret

**With `gh`:** Follow the token setup in Step 2, Section 4 to check and set the secret via `gh secret set`.

**Without `gh`:** Skip this step. Provide the user with the URL to set it manually:
```
https://github.com/OWNER/REPO/settings/secrets/actions
```
If the user hasn't set the token yet, that's OK - when they trigger the bot from an issue, `run-action.sh` will detect the missing token and post a detailed error comment explaining how to set it up (including `claude setup-token` instructions).

### Step 7: Commit and Push Changes

Commit with descriptive message and push to repository

### Step 8: Verify Workflow File

Check that workflow is recognized by GitHub

### Step 9: Run Automated Verification (REQUIRED)

**This step is MANDATORY. Always execute the automated verification.**

The verification process differs based on whether `gh` command is available (checked in Step 2):

#### Option A: With `gh` command (Recommended - Fully Automated)

Execute the complete verification script from the "Testing the Setup" section below. The AI assistant should:

1. **Create a test issue** using `gh issue create`
2. **Add trigger comment** with 🤖 or `/code`
3. **Wait for bot response** - poll the issue comments in a loop (check every 10-30 seconds)
4. **Monitor workflow status** using `gh run list` and `gh run view`
5. **If error occurs:**
   - Check workflow logs with `gh run view --log-failed`
   - Analyze the error
   - Suggest fixes or next steps
6. **Report results** to the user with:
   - Issue URL
   - Bot response (success/failure)
   - Workflow run URL
   - Any errors found

**Do not skip this step.** Wait for the bot to respond completely before finishing setup.

#### Option B: Without `gh` command (Manual Verification)

If `gh` command is not available, guide the user to verify manually.

**Note:** If `CLAUDE_CODE_OAUTH_TOKEN` hasn't been set yet (Step 6 was skipped), that's fine - `run-action.sh` will detect the missing token and post a detailed error comment on the issue explaining exactly how to set it up. This is a valid way to discover and fix configuration issues.

1. **Provide the issue creation URL:**
   ```
   https://github.com/OWNER/REPO/issues/new
   ```

2. **Give example issue content:**
   ```
   Title: Test Claude Coding Robot Setup

   Body:
   This is a test issue to verify the coding robot setup.

   Please respond with a simple message. 🤖
   ```

3. **Instruct the user:**
   - Create the issue using the URL above
   - Wait for the workflow to run (check the Actions tab)
   - The bot will either:
     - ✅ Post a successful response comment
     - ❌ Post an error comment with instructions to fix the issue (e.g. missing token setup guide)
   - Follow any error instructions and try again by commenting 🤖 on the same issue

4. **Provide useful URLs:**
   - Create issue: `https://github.com/OWNER/REPO/issues/new`
   - Actions: `https://github.com/OWNER/REPO/actions`
   - Secrets settings: `https://github.com/OWNER/REPO/settings/secrets/actions`

**Important:** Setup is complete when the bot posts a successful response. Error responses from `run-action.sh` are self-explanatory and guide the user to fix the issue.

### CLAUDE_CODE_OAUTH_TOKEN Secret Verification

Before completing setup, verify the secret exists using this priority:

1. **If `gh` command is available**: Check secret existence via API
   ```bash
   gh api repos/OWNER/REPO/actions/secrets | jq -r '.secrets[].name' | grep -q CLAUDE_CODE_OAUTH_TOKEN
   ```
   - If found: Proceed with commit/push
   - If not found: Warn user and provide setup instructions

2. **If `.github/workflows/claude.yml` exists**: Assume secret is already configured
   - The existing `claude-code-action` setup likely has the secret configured
   - Proceed with commit/push

3. **If neither condition is met**: Warn user
   - Inform them to set up `CLAUDE_CODE_OAUTH_TOKEN` in repository settings
   - Provide setup instructions
   - Still proceed with commit/push (workflow will fail gracefully with clear error)

## Overview

This setup enables Claude to autonomously handle Issues and Pull Requests by:
- Triggering on `/code` or `🤖` in Issue/PR comments
- Running in a devcontainer with full development environment
- Committing and pushing changes directly to branches
- Providing real-time progress updates via comments

## File Structure

Download and create these files in your repository:

```
.github/
  workflows/
    coding-robot.yml          ← Download: curl -O https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml
  claude/
    run-action.sh          ← Download: curl -O https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh
    system.md              ← Download: curl -O https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system.md
.devcontainer/
  devcontainer.json        ← Download: curl -O https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/devcontainer.json
  Dockerfile               ← Download: curl -O https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/Dockerfile
.claude/
  CLAUDE.md                ← Project-specific test instructions (create manually)
```

**Direct Download Links:**
- [coding-robot.yml](https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml)
- [run-action.sh](https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh) ⚠️ Make executable!
- [system.md](https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system.md)
- [devcontainer.json](https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/devcontainer.json)
- [Dockerfile](https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/Dockerfile)

**Important Notes:**
- Make `run-action.sh` executable: `chmod +x .github/coding-robot/run-action.sh`
- All files include the latest bug fixes (see Troubleshooting section)
- The workflow file uses the correct environment variable passing method
- The script uses `--dangerously-skip-permissions` flag (correct as of 2026-01)

## Important: Autonomous Execution Policy

**Claude Bot operates autonomously and should complete tasks end-to-end without stopping for user confirmation, unless:**
- Explicit user instruction is required (ambiguous requirements, multiple valid approaches)
- Critical decisions that could have significant impact
- Security-sensitive operations

**Default behavior: Execute the full task workflow from start to finish.**

When implementing tasks:
- **Read the full request** and understand all requirements
- **Plan the complete solution** before starting
- **Execute all steps** including testing and verification
- **Wait for test results** and validate outputs
- **Fix issues** if tests fail and retry until all tests pass
- **Only stop** when the task is fully complete or requires user input

---

## Configuration Files

### 1. Workflow Configuration

**File:** `.github/workflows/coding-robot.yml`

**📥 [Download](https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml)**

This workflow:
- Triggers on `/code` or `🤖` in Issue/PR comments, titles, or bodies
- Adds 👀 reaction immediately
- Runs Claude Bot in a devcontainer
- Changes reaction to ✅ (success) or ❌ (failure)
- Posts results as comments

**Key Features:**
- ✅ Correct environment variable passing to devcontainer
- ✅ Creates GitHub event JSON file for the bot
- ✅ Proper permissions set for contents, PRs, and issues

---

### 2. Main Automation Script

**File:** `.github/coding-robot/run-action.sh`

**📥 [Download](https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh)**

**Remember to make it executable:**
```bash
chmod +x .github/coding-robot/run-action.sh
```

This script:
- Fetches Issue/PR context via GitHub CLI
- Manages git branches and merge conflicts
- Downloads attached images
- Runs Claude Code Bot with proper authentication
- Commits and pushes changes
- Posts results as GitHub comments
- Handles PR creation errors gracefully

**Key Features:**
- ✅ Uses `--dangerously-skip-permissions` flag (correct!)
- ✅ Graceful PR creation error handling
- ✅ Posts manual PR creation instructions on permission errors
- ✅ Progress updates every 30 seconds

---

### 3. System Prompt

**File:** `.github/coding-robot/system.md`

**📥 [Download](https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system.md)**

This file defines Claude Bot's behavior:
- Two-phase execution (work + report)
- Mandatory test validation
- Commit and push workflows
- Security policies
- Error handling procedures
- Output format requirements

**Important sections:**
- Autonomous execution rules
- Test validation requirements (MANDATORY)
- `/tmp/ccbot-result.md` format (max 3000 chars)
- Artifacts policy for images and large outputs

---

### 4. Devcontainer Configuration

**Files:**
- **📥 [devcontainer.json](https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/devcontainer.json)**
- **📥 [Dockerfile](https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/Dockerfile)**

These configure the development container:
- Based on TypeScript-Node 22 Bookworm image
- Includes git, GitHub CLI, and common utilities
- Installs Claude Code CLI automatically
- Sets up PATH for Claude command

---

### 5. Project Test Configuration

**File:** `.claude/CLAUDE.md`

Create this file with your project-specific test commands:

```markdown
## How to Run Tests

```bash
# Run all tests
# Depending on the project, use one of the following:
# npm test
# pytest
# bundle exec rake test
# go test ./...
# mvn test
```
```

---

## Adapting to Existing Devcontainer

If you already have a `.devcontainer/` setup, you need to add the following.

### Required Commands

The following commands must be available in your devcontainer:
- `git` - Version control
- `gh` (GitHub CLI) - GitHub API operations
- `jq` - JSON processing
- `curl` - Downloads and API calls
- `file` - File type detection
- `timeout` - Command timeout control (usually included in coreutils)

If any of these are missing, add them via Dockerfile or devcontainer features.

### Installing Claude Code CLI

Add the following to your existing Dockerfile or devcontainer configuration:

**For Dockerfile:**
```dockerfile
# After switching to non-root user (e.g., USER node, USER vscode)
USER your_user_name

# Install Claude Code CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

# Add to PATH
ENV PATH="/home/your_user_name/.local/bin:${PATH}"
```

**For devcontainer.json:**
```json
{
  "postCreateCommand": "curl -fsSL https://claude.ai/install.sh | bash && echo 'export PATH=\"$HOME/.local/bin:$PATH\"' >> ~/.bashrc"
}
```

### Important Notes

- Install Claude CLI as the same user specified in `remoteUser`
- Always add `~/.local/bin` to PATH
- `.github/workflows/coding-robot.yml` and `.github/coding-robot/` directory are required
- Set `CLAUDE_CODE_OAUTH_TOKEN` as a GitHub repository secret

**Reference**: For a complete configuration example for new setups, download the files from this gist.

---

## Testing the Setup

After completing the setup and pushing changes, verify the installation works correctly.

### Verification Method Selection

Choose the verification method based on `gh` CLI availability:

#### Method A: Automatic Verification (with `gh` command) - Recommended

If `gh` command is available, AI assistants can fully automate the verification process.

**What the AI assistant will do:**
1. Create a test issue automatically
2. Add trigger comment with 🤖
3. Poll for bot response (check every 10 seconds, wait up to 10 minutes)
4. Monitor workflow execution status
5. Check for errors in workflow logs if failed
6. Report complete results with URLs

**Complete Verification Script:**

```bash
#!/bin/bash
set -e

echo "🔍 Starting Claude Bot verification..."

# Step 1: Verify gh command
if ! command -v gh &> /dev/null; then
    echo "❌ Error: gh command not found. Please install GitHub CLI."
    exit 1
fi
echo "✅ GitHub CLI found: $(gh --version | head -1)"

# Step 2: Create test issue and capture URL
echo ""
echo "📝 Creating test issue..."
ISSUE_URL=$(gh issue create --title "Claude Bot 動作確認テスト" --body "OSのバージョン番号を教えて 🤖")
ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
echo "✅ Test issue created: $ISSUE_URL"

# Step 3: Wait for workflow to start (with timeout)
echo ""
echo "⏳ Waiting for workflow to start..."
WAIT_COUNT=0
MAX_WAIT=30
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 3
    RUN_ID=$(gh run list --workflow="coding-robot.yml" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
    if [ -n "$RUN_ID" ]; then
        echo "✅ Workflow started (Run ID: $RUN_ID)"
        break
    fi
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ -z "$RUN_ID" ]; then
    echo "⚠️  Warning: Workflow did not start within 90 seconds"
    echo "   Check: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
    exit 1
fi

# Step 4: Monitor workflow execution with progress updates
echo ""
echo "🔄 Monitoring workflow execution..."
WORKFLOW_URL="https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions/runs/$RUN_ID"
echo "   Workflow URL: $WORKFLOW_URL"

ELAPSED=0
while true; do
    WORKFLOW_STATUS=$(gh run view $RUN_ID --json status,conclusion --jq '.status' 2>/dev/null || echo "unknown")

    if [ "$WORKFLOW_STATUS" = "completed" ]; then
        CONCLUSION=$(gh run view $RUN_ID --json conclusion --jq '.conclusion')
        echo ""
        if [ "$CONCLUSION" = "success" ]; then
            echo "✅ Workflow completed successfully!"
        else
            echo "❌ Workflow failed with conclusion: $CONCLUSION"
        fi
        break
    fi

    # Progress update every 30 seconds
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo "   Status: $WORKFLOW_STATUS (${ELAPSED}s elapsed...)"
    fi

    sleep 10
    ELAPSED=$((ELAPSED + 10))

    # Timeout after 10 minutes
    if [ $ELAPSED -gt 600 ]; then
        echo "⚠️  Workflow timeout (10 minutes exceeded)"
        echo "   Check workflow logs: gh run view $RUN_ID --log"
        break
    fi
done

# Step 5: Display issue comments
echo ""
echo "💬 Claude Bot response:"
echo "----------------------------------------"
gh issue view $ISSUE_NUMBER --comments 2>/dev/null || echo "Could not fetch comments"
echo "----------------------------------------"

# Step 6: Check for errors and display logs if needed
if [ "$CONCLUSION" != "success" ]; then
    echo ""
    echo "📋 Workflow logs (failed steps):"
    echo "----------------------------------------"
    gh run view $RUN_ID --log-failed 2>/dev/null || gh run view $RUN_ID --log 2>/dev/null || echo "Could not fetch logs"
    echo "----------------------------------------"
fi

# Step 7: Summary report
echo ""
echo "📊 Verification Summary:"
echo "   Issue: $ISSUE_URL"
echo "   Workflow: $WORKFLOW_URL"
echo "   Status: $CONCLUSION"
echo ""

if [ "$CONCLUSION" = "success" ]; then
    echo "✅ Claude Bot setup verification completed successfully!"
    echo ""
    echo "Next steps:"
    echo "- Try creating an issue with 🤖 to trigger the bot"
    echo "- Or comment '/code' on any existing issue/PR"
else
    echo "❌ Verification failed. Please check:"
    echo "1. Workflow logs above for error details"
    echo "2. Troubleshooting section in the gist"
    echo "3. Repository secrets (CLAUDE_CODE_OAUTH_TOKEN)"
fi
```

**Usage:**

When completing the setup, the AI assistant should:
1. Save the above script to a temporary file
2. Execute it with bash
3. Report the results to the user
4. Include the issue URL and workflow URL in the final report

**Alternative: Step-by-step execution**

If you prefer to execute each step individually, use the commands from the script above separately. The integrated script provides better error handling and progress reporting.

---

#### Method B: Manual Verification (without `gh` command)

If `gh` command is not available, the AI assistant should guide the user through manual verification:

**AI Assistant Instructions:**

1. **Get repository information** (from git remote or user confirmation):
   ```bash
   REPO_URL=$(git remote get-url origin)
   # Extract owner and repo name from URL
   ```

2. **Provide issue creation URL to user:**
   ```
   Please create a test issue here:
   https://github.com/OWNER/REPO/issues/new
   ```

3. **Provide example issue content:**
   ```markdown
   Title: Test Claude Coding Robot Setup

   Body:
   This is a test issue to verify the coding robot setup.

   Please respond with the current OS version. 🤖
   ```

4. **Instruct the user:**
   - Click the URL above to create the issue
   - Copy and paste the example content
   - Submit the issue
   - Wait 1-2 minutes for the workflow to start
   - Check the Actions tab: `https://github.com/OWNER/REPO/actions`
   - Wait for the bot to post a comment (may take 2-10 minutes depending on task complexity)
   - Report back here with:
     - ✅ Success: Bot responded with a comment
     - ❌ Error: No response or workflow failed

5. **If user reports an error:**
   - Ask them to check the workflow logs: `https://github.com/OWNER/REPO/actions/workflows/coding-robot.yml`
   - Guide them to click on the failed run
   - Ask them to copy the error message from the logs
   - Analyze the error and provide troubleshooting steps

**Important:** Do not proceed to the next step until the user confirms the bot responded successfully or reports an error for troubleshooting.

---

## Troubleshooting

### Common Issues and Fixes

#### 1. `GITHUB_TOKEN is not set` Error

**Problem:** Environment variables not passed to devcontainer.

**Fix:** The latest `coding-robot.yml` file ([📥 download](https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml)) already includes the fix.

The workflow exports environment variables within `runCmd`:

```yaml
runCmd: |
  # Export environment variables in runCmd
  export CLAUDE_CODE_OAUTH_TOKEN="${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}"
  export GITHUB_TOKEN="${{ secrets.GITHUB_TOKEN }}"
  export GITHUB_REPOSITORY="${{ github.repository }}"
  export GITHUB_EVENT_NAME="${{ github.event_name }}"

  # Create event JSON file
  cat > /tmp/github_event.json << 'EVENTEOF'
  ${{ toJSON(github.event) }}
  EVENTEOF
  export GITHUB_EVENT_PATH="/tmp/github_event.json"

  cd /workspaces/*
  bash .github/coding-robot/run-action.sh
```

#### 2. Incorrect Claude CLI Flag Error

**Problem:** Using wrong flag name.

**Fix:** The latest `run-action.sh` file ([📥 download](https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh)) uses the correct flag:

```bash
timeout 1800 claude \
  --output-format json \
  --dangerously-skip-permissions \
  <<EOF > "$OUTPUT_FILE" 2>&1
```

**Note:** The correct flag is `--dangerously-skip-permissions`.

#### 3. `GitHub Actions is not permitted to create or approve pull requests` Error

**Problem:** Repository settings don't allow GitHub Actions to create PRs.

**Fix Option 1 - Enable in Settings (Recommended):**
1. Go to repository Settings → Actions → General
2. Scroll to "Workflow permissions"
3. Enable "Allow GitHub Actions to create and approve pull requests"
4. Save changes

**Fix Option 2 - Handled gracefully in script:**

The latest `run-action.sh` handles this automatically by:
- Catching the PR creation error
- Posting a comment with manual PR creation instructions
- Not failing the workflow

This is already implemented in the provided script.

#### 4. Bot executes but creates no changes

**Possible causes:**
- Claude didn't write to `/tmp/ccbot-result.md`
- No actual file changes were needed
- Claude encountered an error during execution

**Check:**
- Workflow logs for Claude's output
- Issue comments for error messages
- Ensure the task is clear and actionable

#### 5. `grep: lookbehind assertion is not fixed length` Warning

**Problem:** The grep version in the container doesn't support the regex pattern used for image extraction.

**Impact:** Minor - image extraction might not work, but this doesn't affect core functionality.

**Fix (optional):** Use a simpler regex pattern or install GNU grep in the Dockerfile.

---

## Summary of Setup Flow for AI Assistants

When executing this setup guide, follow this complete flow:

1. **Create Task List (before any other work)**
   - Use your task management / TODO list tool to create tasks for ALL steps below
   - Do not proceed to step 2 until the task list exists
   - Mark each task as in_progress/completed as you work through it

1. ✅ **Verify Prerequisites**
   - Check if `gh` command is available
   - Check if `CLAUDE_CODE_OAUTH_TOKEN` secret exists

2. ✅ **Create Files**
   - Download and create all files from this gist (see File Structure section)
   - Make `run-action.sh` executable: `chmod +x .github/coding-robot/run-action.sh`

3. ✅ **Commit and Push**
   ```bash
   git add .
   git commit -m "🤖 Add Claude Code Bot - GitHub Actions integration"
   git push
   ```

4. ✅ **Verify Workflow**
   ```bash
   gh workflow list
   ```

5. ✅ **Run Automated Test (REQUIRED)**

   **This step is MANDATORY - do not skip.**

   Execute the complete verification script from the "Testing the Setup" section.
   The script will:
   - Create a test issue with 🤖
   - Wait for workflow to start
   - Monitor execution progress
   - Display bot's response
   - Report success/failure

   **Do not proceed to step 6 until this test passes.**

6. ✅ **Report Results**
   - If test successful: Confirm setup is complete
   - If test failed: Report specific errors and fixes applied
   - Always show the test issue URL and workflow run URL

---

## Quick Reference

**Trigger the bot:**
- Comment `/code` or `🤖` on any Issue or PR

**Monitor execution:**
```bash
gh run list --workflow="coding-robot.yml" --limit 5
gh run view [RUN_ID] --log
```

**Check bot responses:**
```bash
gh issue view [ISSUE_NUMBER] --comments
```

**Enable PR creation:**
Settings → Actions → General → "Allow GitHub Actions to create and approve pull requests"

**Required secrets:**
- `CLAUDE_CODE_OAUTH_TOKEN` (required)
- `GITHUB_TOKEN` (automatic)

**Download all files:**
```bash
# Create directories
mkdir -p .github/workflows .github/coding-robot .devcontainer

# Download files
curl -o .github/workflows/coding-robot.yml https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml
curl -o .github/coding-robot/run-action.sh https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh
curl -o .github/coding-robot/system.md https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system.md
curl -o .devcontainer/devcontainer.json https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/devcontainer.json
curl -o .devcontainer/Dockerfile https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/Dockerfile

# Make script executable
chmod +x .github/coding-robot/run-action.sh
```

---

**For issues or questions, check the GitHub Actions logs first, then refer to the Troubleshooting section above.**

