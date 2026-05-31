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
| **A: Update** | `.github/workflows/coding-robot.yml` exists | Update only coding-robot files (`coding-robot.yml`, `coding-robot-finalize.yml`, `run-action.sh`, `system.md`, `system-codex.md`, `_issue.md`, `_pr.md`, `_pdh.md`, `engines/_*.sh`). Do not touch `.devcontainer/`, `.claude/CLAUDE.md`, or any other existing files. Skip to Step 6 after downloading. |
| **B: New + existing devcontainer** | No workflow file, but `.devcontainer/` exists | Download workflow/script/system.md. Do not overwrite any devcontainer files. Instead, adapt the existing devcontainer (Step 5). |
| **C: New + no devcontainer** | No workflow file, no `.devcontainer/` | Download all files including devcontainer files. |

For all types: if `.claude/CLAUDE.md` exists, do not overwrite it.

### Step 4: Download and Place Files

Create the necessary directories and download files according to the install type determined in Step 3.

**Files to download — see the "File URLs" section below for URLs.**

| File | Type A (update) | Type B (new + existing devcontainer) | Type C (new) |
|------|-----------------|--------------------------------------|--------------|
| `.github/workflows/coding-robot.yml` | Yes | Yes | Yes |
| `.github/workflows/coding-robot-finalize.yml` | Yes | Yes | Yes |
| `.github/coding-robot/run-action.sh` | Yes | Yes | Yes |
| `.github/coding-robot/system.md` | Yes | Yes | Yes |
| `.github/coding-robot/system-codex.md` | Yes | Yes | Yes |
| `.github/coding-robot/_issue.md` | Yes | Yes | Yes |
| `.github/coding-robot/_pr.md` | Yes | Yes | Yes |
| `.github/coding-robot/_pdh.md` | Yes | Yes | Yes |
| `.github/coding-robot/engines/_claude.sh` | Yes | Yes | Yes |
| `.github/coding-robot/engines/_codex.sh` | Yes | Yes | Yes |
| `.devcontainer/devcontainer.json` | No | No | Yes |
| `.devcontainer/docker-compose.yml` | No | No | Yes |
| `.devcontainer/Dockerfile` | No | No | Yes |
| `scripts/dev/up` | No | No | Yes |
| `scripts/dev/down` | No | No | Yes |
| `scripts/dev/bash` | No | No | Yes |
| `scripts/dev/rebuild` | No | No | Yes |
| `scripts/dev/stop` | No | No | Yes |
| `scripts/dev/logs` | No | No | Yes |

After downloading, make `run-action.sh` and all `scripts/dev/*` executable (`chmod +x`). The `engines/_*.sh` files are sourced by `run-action.sh` (not executed directly), so they do not need `chmod +x`, but they MUST be present — `run-action.sh` will fail without the engine file for the selected engine.

**Engine selection (optional):** Both engines are always installed. The active one is chosen at runtime by the repository variable `CODING_ROBOT_ENGINE` (`claude` is the default, `codex` switches to Codex). Switching engines is config-only — no re-install required.

If `.claude/CLAUDE.md` does not exist, create it with a basic template that includes a "How to Run Tests" section. Ask the user what test command their project uses, or use a placeholder if the project type is obvious.

### Step 5: Adapt Existing Devcontainer (Type B Only)

Skip this step if the install type is A or C.

Your existing devcontainer must meet the requirements listed in the "Devcontainer Requirements" section below. Check each requirement against the existing `Dockerfile` and `devcontainer.json`, and add whatever is missing. Do not remove or replace existing configuration — only add to it.

### Step 6: Set Up Engine Credentials

Both engines are installed; only the one selected by `CODING_ROBOT_ENGINE` runs. Set the credential for whichever engine(s) you may want to use — you can set both now and switch between engines later by flipping the variable. If the credential for the active engine is missing, `run-action.sh` detects it at runtime and posts a detailed error comment with setup instructions.

#### Claude engine (default): `CLAUDE_CODE_OAUTH_TOKEN`

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

#### Codex engine: `CODEX_AUTH_JSON`

Use **one** of the following:

- **`CODEX_AUTH_JSON`** (use the user's ChatGPT plan): the user runs `codex login` locally, then provides their auth file **as a single line**: `jq -c . ~/.codex/auth.json`. Set it with `gh secret set CODEX_AUTH_JSON` (or via the Secrets page). It must be one line — a multi-line value breaks the workflow env passing.
- **`OPENAI_API_KEY`** (API-key billing): set the user's OpenAI API key as a secret.

> Note: with `CODEX_AUTH_JSON`, the access token is refreshed at runtime but the refreshed copy is discarded (the container is ephemeral). If auth eventually fails, the user re-runs `codex login` locally and updates the secret.

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

After successful verification, tell the user how to use Coding Robot: comment `:robot:` (or paste the 🤖 emoji) on any Issue or PR.

If you modified any existing files during setup (e.g., `Dockerfile`, `devcontainer.json`, shell profile), list every change you made and explain why. The user needs to review these changes.

---

## File URLs

| File | URL | Notes |
|------|-----|-------|
| `.github/workflows/coding-robot.yml` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml` | |
| `.github/workflows/coding-robot-finalize.yml` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot-finalize.yml` | Finalizes tickets when a bot PR is merged (PDH repos); harmless if unused |
| `.github/coding-robot/run-action.sh` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh` | `chmod +x` after download |
| `.github/coding-robot/system.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system.md` | |
| `.github/coding-robot/system-codex.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system-codex.md` | |
| `.github/coding-robot/_issue.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/_issue.md` | Issue-context prompt, read by run-action.sh |
| `.github/coding-robot/_pr.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/_pr.md` | PR-context prompt, read by run-action.sh |
| `.github/coding-robot/_pdh.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/_pdh.md` | PDH-mode prompt, read when `product-brief.md`/`tickets/` exist |
| `.github/coding-robot/engines/_claude.sh` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/engines/_claude.sh` | sourced by run-action.sh |
| `.github/coding-robot/engines/_codex.sh` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/engines/_codex.sh` | sourced by run-action.sh |
| `.devcontainer/devcontainer.json` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.devcontainer/devcontainer.json` | Type C only |
| `.devcontainer/docker-compose.yml` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.devcontainer/docker-compose.yml` | Type C only |
| `.devcontainer/Dockerfile` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.devcontainer/Dockerfile` | Type C only |
| `scripts/dev/up` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/scripts/dev/up` | Type C only, `chmod +x` |
| `scripts/dev/down` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/scripts/dev/down` | Type C only, `chmod +x` |
| `scripts/dev/bash` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/scripts/dev/bash` | Type C only, `chmod +x` |
| `scripts/dev/rebuild` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/scripts/dev/rebuild` | Type C only, `chmod +x` |
| `scripts/dev/stop` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/scripts/dev/stop` | Type C only, `chmod +x` |
| `scripts/dev/logs` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/scripts/dev/logs` | Type C only, `chmod +x` |

---

## Devcontainer Requirements

When adapting an existing devcontainer (Type B), ensure the following:

**Required commands** (before adding devcontainer features, check the Dockerfile and existing configuration — many base images already include these tools):
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

**Codex CLI:**
- Install: `npm install -g @openai/codex`
- Ensure the global npm bin directory is on `PATH` for `remoteUser`

Install both CLIs unconditionally — the active engine is chosen at runtime via the `CODING_ROBOT_ENGINE` variable, not at install time.

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
