# Coding Robot — Setup Guide

You are the setup executor. Your job is to install Coding Robot into the user's repository by following the steps below. Coding Robot is a separate system that runs later in GitHub Actions using `system.md` as its instructions — you do not need to understand its runtime behavior to complete this setup.

Always respond in the language used by the user in their request or in previous conversations.

---

## Setup Steps

### Step 1: Create a Task List

Before doing anything else, create a task for each of the steps below using your task management tool. Do not check prerequisites, download files, or run any commands until the task list exists.

This setup has 9 interdependent steps. Without a task list to track progress, steps get skipped and setup fails silently.

Tasks to create:
1. Create task list (this step)
2. Check prerequisites
3. Check existing files and determine install type
4. Download and place files
5. Adapt existing devcontainer (if install type B)
6. Set up CLAUDE_CODE_OAUTH_TOKEN
7. Commit and push changes
8. Verify workflow registration
9. End-to-end verification

After creating all tasks, mark Step 1 as completed, then begin Step 2.

### Step 2: Check Prerequisites

Check the following. Record the results — they affect later steps.

- **Current branch**: You must be on the default branch (usually `main`). The workflow file must exist on the default branch for GitHub Actions to recognize it. If not on the default branch, switch before proceeding.
- **gh CLI**: Is it installed? If yes, is it authenticated (`gh auth status`)? Record whether gh is usable (installed + authenticated).
- **git remote origin**: Does it point to a GitHub repository? Extract the `OWNER/REPO` string. If no remote exists, stop and ask the user.

How gh availability affects later steps:

| Step | With gh | Without gh |
|------|---------|------------|
| Step 6: Token setup | Check/set secret via `gh secret set` | Skip — user sets it manually in GitHub Settings |
| Step 9: Verification | Automated: create issue, poll for response, check logs | Manual: user creates issue from browser |

### Step 3: Check Existing Files and Determine Install Type

Check for the existence of these files/directories:

- `.github/workflows/coding-robot.yml`
- `.devcontainer/`
- `.github/coding-robot/`
- `.claude/CLAUDE.md`

Based on the results, determine the install type:

| Type | Condition | What to do |
|------|-----------|------------|
| **A: Update** | `.github/workflows/coding-robot.yml` exists | Update only coding-robot files (workflow, script, system.md). Do not touch `.devcontainer/`, `.claude/CLAUDE.md`, or any other existing files. Skip to Step 6 after downloading. |
| **B: New + existing devcontainer** | No workflow file, but `.devcontainer/` exists | Download workflow/script/system.md. Do not overwrite any devcontainer files. Instead, adapt the existing devcontainer (Step 5). |
| **C: New + no devcontainer** | No workflow file, no `.devcontainer/` | Download all files including devcontainer files. |

For all types: if `.claude/CLAUDE.md` exists, do not overwrite it.

### Step 4: Download and Place Files

Create the necessary directories and download files according to the install type determined in Step 3.

**Files to download — see the "File URLs" section below for URLs.**

| File | Type A (update) | Type B (new + existing devcontainer) | Type C (new) |
|------|-----------------|--------------------------------------|--------------|
| `.github/workflows/coding-robot.yml` | Yes | Yes | Yes |
| `.github/coding-robot/run-action.sh` | Yes | Yes | Yes |
| `.github/coding-robot/system.md` | Yes | Yes | Yes |
| `.devcontainer/devcontainer.json` | No | No | Yes |
| `.devcontainer/Dockerfile` | No | No | Yes |

After downloading, make `run-action.sh` executable (`chmod +x`).

If `.claude/CLAUDE.md` does not exist, create it with a basic template that includes a "How to Run Tests" section. Ask the user what test command their project uses, or use a placeholder if the project type is obvious.

### Step 5: Adapt Existing Devcontainer (Type B Only)

Skip this step if the install type is A or C.

Your existing devcontainer must meet the requirements listed in the "Devcontainer Requirements" section below. Check each requirement against the existing `Dockerfile` and `devcontainer.json`, and add whatever is missing. Do not remove or replace existing configuration — only add to it.

### Step 6: Set Up CLAUDE_CODE_OAUTH_TOKEN

**Constraint:** `claude setup-token` requires interactive browser authentication. You cannot run it. The user must run it in a separate terminal.

**With gh:**

1. Check if the secret already exists: query the repository secrets API.
2. If it exists, skip to Step 7.
3. If it does not exist:
   - Tell the user to run `claude setup-token` in a separate terminal.
   - Wait for the user to paste the token value.
   - Set the secret using `gh secret set CLAUDE_CODE_OAUTH_TOKEN`.

**Without gh:**

Tell the user to set `CLAUDE_CODE_OAUTH_TOKEN` in their repository's Settings > Secrets and variables > Actions. Provide the direct URL: `https://github.com/OWNER/REPO/settings/secrets/actions`

If the token is not set yet, that is acceptable — `run-action.sh` will detect the missing token at runtime and post a detailed error comment with setup instructions.

### Step 7: Commit and Push Changes

Commit all new/changed files with a descriptive message and push to the default branch. The workflow file must be on the default branch for GitHub Actions to recognize it.

### Step 8: Verify Workflow Registration

Confirm the workflow file is recognized by GitHub. With gh, run `gh workflow list` and check that `coding-robot` appears. Without gh, tell the user to check the Actions tab.

### Step 9: End-to-End Verification

This step is mandatory. Do not skip it.

**With gh (automated):**

1. Create a test issue (e.g., title: "Test Coding Robot Setup", body includes a simple task request and the trigger emoji).
2. Wait for the workflow to start. Poll `gh run list` until a run appears.
3. Monitor the workflow run until completion.
4. Check the issue comments for the bot's response.
5. If the workflow failed, check logs with `gh run view --log-failed` and analyze the error.
6. Report results to the user: issue URL, workflow URL, success/failure, any errors.

**Without gh (manual):**

Provide the user with:
- The issue creation URL: `https://github.com/OWNER/REPO/issues/new`
- Example issue content (title and body with trigger emoji)
- The Actions tab URL to monitor: `https://github.com/OWNER/REPO/actions`

Tell the user to create the issue, wait for the bot response, and report back. If the bot posts an error comment, the error message is self-explanatory and includes fix instructions.

If verification fails, refer to the Troubleshooting section.

After successful verification, tell the user how to use Coding Robot: comment `/code` or the trigger emoji on any Issue or PR.

If you modified any existing files during setup (e.g., `Dockerfile`, `devcontainer.json`, shell profile), list every change you made and explain why. The user needs to review these changes.

Additionally, check whether the devcontainer uses `postCreateCommand` or `postStartCommand`. Coding Robot uses `devcontainer-cli` which does **not** execute these lifecycle hooks. If they are present and install tools or configure the environment needed at runtime, warn the user and suggest moving those steps into the Dockerfile so they take effect during bot execution.

---

## File URLs

| File | URL | Notes |
|------|-----|-------|
| `.github/workflows/coding-robot.yml` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml` | |
| `.github/coding-robot/run-action.sh` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh` | `chmod +x` after download |
| `.github/coding-robot/system.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system.md` | |
| `.devcontainer/devcontainer.json` | `https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/devcontainer.json` | Type C only |
| `.devcontainer/Dockerfile` | `https://gist.githubusercontent.com/masuidrive/3bd621d7c64a408fd5a1835302c3cf61/raw/Dockerfile` | Type C only |

---

## Devcontainer Requirements

When adapting an existing devcontainer (Type B), ensure the following:

**Required commands** (install via Dockerfile or devcontainer features if missing):
- `git`
- `gh` (GitHub CLI)
- `jq`
- `curl`
- `file`
- `timeout` (usually included in coreutils)

**Claude Code CLI:**
- Install: `curl -fsSL https://claude.ai/install.sh | bash`
- Install as the same user specified in `remoteUser`
- Add `~/.local/bin` to `PATH` (via `ENV` in Dockerfile or shell profile)

---

## Troubleshooting

### 1. `GITHUB_TOKEN is not set` Error

**Cause:** Environment variables not passed to devcontainer.

**Fix:** The latest `coding-robot.yml` already includes the fix. Re-download it from the URL in the File URLs section. The workflow exports environment variables within `runCmd`.

### 2. Incorrect Claude CLI Flag Error

**Cause:** Wrong flag name for Claude CLI.

**Fix:** The correct flag is `--dangerously-skip-permissions`. Re-download `run-action.sh` from the File URLs section.

### 3. `GitHub Actions is not permitted to create or approve pull requests` Error

**Cause:** Repository settings don't allow GitHub Actions to create PRs.

**Fix:** Go to repository Settings > Actions > General > Workflow permissions, and enable "Allow GitHub Actions to create and approve pull requests".

Note: The latest `run-action.sh` handles this error gracefully by posting a comment with manual PR creation instructions instead of failing the workflow.

### 4. Bot executes but creates no changes

**Possible causes:**
- Claude didn't write to `/tmp/ccbot-result.md`
- No actual file changes were needed
- Claude encountered an error during execution

**Check:** Workflow logs for Claude's output and issue comments for error messages.

### 5. `grep: lookbehind assertion is not fixed length` Warning

**Impact:** Minor — image extraction might not work, but core functionality is unaffected.

**Fix (optional):** Use a simpler regex pattern or install GNU grep in the Dockerfile.
