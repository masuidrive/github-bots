# Coding Robot — Setup Guide

You are the setup executor. Your job is to install Coding Robot into the user's repository by following the steps below. Coding Robot is a separate system that runs later in GitHub Actions using `system.md` (shared rules) concatenated with `system-claude.md` / `system-codex.md` (engine-specific behavior, selected by `CODING_ROBOT_ENGINE`) as its instructions — you do not need to understand its runtime behavior to complete this setup.

Always respond in the language used by the user in their request or in previous conversations.

---

## Setup Steps

### Step 1: Create a Task List

Before doing anything else, create a task for each of the steps below using your task management tool. Do not check prerequisites, download files, or run any commands until the task list exists.

This setup has 10 interdependent steps. Without a task list to track progress, steps get skipped and setup fails silently.

Tasks to create:
1. Create task list (this step)
2. Check prerequisites
3. Check existing files and determine install type
4. Download and place files
5. Adapt existing devcontainer (if install type B)
6. Set up engine credentials
7. Configure PR merge settings (PDH-friendly)
8. Commit and push changes
9. Verify workflow registration
10. End-to-end verification

After creating all tasks, mark Step 1 as completed, then begin Step 2.

### Step 2: Check Prerequisites

Check the following. Record the results — they affect later steps.

- **Current branch**: You must be on the default branch (usually `main`). The workflow file must exist on the default branch for GitHub Actions to recognize it. If not on the default branch, switch before proceeding.
- **gh CLI**: Is it installed? If yes, is it authenticated (`gh auth status`)? Record whether gh is usable (installed + authenticated).
- **git remote origin**: Does it point to a GitHub repository? Extract the `OWNER/REPO` string. If no remote exists, stop and ask the user.

How gh availability affects later steps:

| Step | With gh | Without gh |
|------|---------|------------|
| Step 6: Credentials | Check/set secret via `gh secret set` | Skip — user sets it manually in GitHub Settings |
| Step 7: PR merge settings | Apply via `gh repo edit` + `gh api` | Skip — user toggles them in repo Settings → General |
| Step 10: Verification | Automated: create issue, poll for response, check logs | Manual: user creates issue from browser |

### Step 3: Check Existing Files and Determine Install Type

Check for the existence of these files/directories:

- `.github/workflows/coding-robot.yml`
- `.devcontainer/`
- `.github/coding-robot/`
- `.claude/CLAUDE.md`

Based on the results, determine the install type:

| Type | Condition | What to do |
|------|-----------|------------|
| **A: Update** | `.github/workflows/coding-robot.yml` exists | Update only coding-robot files (`coding-robot.yml`, `coding-robot-finalize.yml`, `run-action.sh`, `system.md`, `system-claude.md`, `system-codex.md`, `_issue.md`, `_pr.md`, `_pdh.md`, `engines/_*.sh`). Do not touch `.devcontainer/`, `.claude/CLAUDE.md`, or any other existing files. Skip to Step 6 after downloading. |
| **B: New + existing devcontainer** | No workflow file, but `.devcontainer/` exists | Download workflow/script/`system-*.md`. Do not overwrite any devcontainer files. Instead, adapt the existing devcontainer (Step 5). |
| **C: New + no devcontainer** | No workflow file, no `.devcontainer/` | Download all files including devcontainer files. |

For all types: if `.claude/CLAUDE.md` exists, do not overwrite it.

> **Type A note**: this manual flow is for the **first** install (or installs from before the self-update mechanism existed). Once the bot is installed, **routine updates are done by asking the bot to update itself** — see [`UPDATE.md`](.github/coding-robot/UPDATE.md). You only need this Type A path if (a) the bot is too broken to self-update, or (b) you want to inspect each file by hand.

### Step 4: Download and Place Files

Create the necessary directories and download files according to the install type determined in Step 3.

**Files to download — see the "File URLs" section below for URLs.**

| File | Type A (update) | Type B (new + existing devcontainer) | Type C (new) |
|------|-----------------|--------------------------------------|--------------|
| `.github/workflows/coding-robot.yml` | Yes | Yes | Yes |
| `.github/workflows/coding-robot-finalize.yml` | Yes | Yes | Yes |
| `.github/coding-robot/run-action.sh` | Yes | Yes | Yes |
| `.github/coding-robot/system.md` | Yes | Yes | Yes |
| `.github/coding-robot/system-claude.md` | Yes | Yes | Yes |
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

**Engine selection (REQUIRED):** Both engine CLIs are installed in the devcontainer, but the active one must be chosen by setting the repository variable `CODING_ROBOT_ENGINE` to either `claude` or `codex`. There is no default — if the variable is unset, the workflow fails fast with a clear message. Switching engines later is config-only (just change the variable; no re-install).

If `.claude/CLAUDE.md` does not exist, create it with a basic template that includes a "How to Run Tests" section. Ask the user what test command their project uses, or use a placeholder if the project type is obvious.

### Step 5: Adapt Existing Devcontainer (Type B Only)

Skip this step if the install type is A or C.

Your existing devcontainer must meet the requirements listed in the "Devcontainer Requirements" section below. Check each requirement against the existing `Dockerfile` and `devcontainer.json`, and add whatever is missing. Do not remove or replace existing configuration — only add to it.

### Step 6: Set Up Engine Credentials

Set the credential for the engine chosen in Step 4 (`CODING_ROBOT_ENGINE`).

**Procedure (applies to whichever credential you set):**

1. **Check if the secret already exists** (`gh secret list`, or the repo Secrets page). If it does, skip ahead.
2. **Set it** using the engine-specific command in the matching subsection below.
3. **Without `gh`**: have the user paste the value at `https://github.com/OWNER/REPO/settings/secrets/actions` (Secrets tab).

If the active engine's credential is missing at runtime, `run-action.sh` detects it and posts a comment with exact fix instructions — a not-yet-set secret never fails silently.

#### `claude`: `CLAUDE_CODE_OAUTH_TOKEN`

`claude setup-token` requires interactive browser authentication — **the user** must run it in a separate terminal (you cannot). Wait for them to paste the token, then:

```bash
gh secret set CLAUDE_CODE_OAUTH_TOKEN
```

#### `codex`: `CODEX_AUTH_JSON` **or** `OPENAI_API_KEY`

Pick **one** option (not both):

- **`CODEX_AUTH_JSON`** — uses the user's ChatGPT plan. The user runs `codex login` locally, then provides the auth file **as a single line** (a multi-line value breaks the workflow env passing):
  ```bash
  jq -c . ~/.codex/auth.json | gh secret set CODEX_AUTH_JSON
  ```
  > The access token is refreshed at runtime but the refreshed copy is discarded (ephemeral container). If auth eventually fails, the user re-runs `codex login` locally and updates the secret.
- **`OPENAI_API_KEY`** — API-key billing:
  ```bash
  gh secret set OPENAI_API_KEY
  ```

#### Offer to also set the other engine's credential

After the chosen engine's secret is in place, **ask the user**:

> You picked `<ENGINE>`. Do you also want to set the credential for the other engine now, so you can switch later just by changing `CODING_ROBOT_ENGINE`? (yes / no)

If **yes**, repeat the matching subsection above for the other engine. If **no**, skip — they can add it later. Do not set both without asking.

#### Project app env (`ENV_JSON`) — optional

The agent's test suites may need project-specific env that this generic
workflow does **not** enumerate — e.g. provider API keys for real-API E2E
tests. Instead of adding each key to `coding-robot.yml`, set **one** secret
`ENV_JSON` holding a JSON object of `{ "KEY": "value", ... }`. `run-action.sh`
decodes it at startup and exports each pair into the agent and its
subprocesses; values are masked in Actions logs and never printed, and each
pair is applied via `export` (no `eval`, so a value can't inject shell).
Invalid JSON is skipped with a warning rather than failing the run.

```bash
gh secret set ENV_JSON --body '{"SOME_API_KEY":"...","OTHER_KEY":"..."}'
```

To populate it from a local `.env`, include **only the keys the tests need**
and **exclude infrastructure/auth config** that would override the CI harness
(database URLs, base URLs, mode flags, OAuth client secrets, app admin keys):

```bash
# adjust KEEP to your project's provider/test credentials
python3 - <<'PY' | gh secret set ENV_JSON
import json
KEEP={"SOME_PROVIDER_API_KEY","ANOTHER_PROVIDER_API_KEY"}
out={}
for line in open(".env"):
    s=line.strip()
    if not s or s.startswith("#") or "=" not in s: continue
    k,v=s.split("=",1); k=k.strip()
    if k in KEEP:
        out[k]=v.strip().strip('"').strip("'")
print(json.dumps(out))
PY
```

> ⚠️ Do **not** dump the entire `.env`. Injecting `*_DATABASE_URL`, `*_MODE`,
> OAuth secrets, or app admin keys can override the test harness and break
> runs in confusing ways. Keep `ENV_JSON` to provider/test credentials only.

### Step 7: Configure Pull Request Merge Settings (PDH-friendly)

These repo-level settings make PR merges align with the PDH ticket boundary: the PR title (which the bot writes to summarize the **entire** branch / ticket scope) becomes the squash commit title, and the PR body (Why / What / Verification) becomes the commit message. Allowing merge commits or rebase would split or fragment the ticket history on `main`, so PDH expects squash-only.

**Target settings:**
- Allow squash merging: **ON**
- Allow merge commits: **OFF**
- Allow rebase merging: **OFF**
- Default commit message (for squash): **Pull request title and description**

**Procedure:**

1. **Show the current state** so the user can see what would change:
   ```bash
   gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
   gh api "repos/$OWNER/$REPO" --jq '{squash_merge_commit_title, squash_merge_commit_message}'
   ```

2. **Explain and confirm.** Ask the user:

   > PDH-style PRs expect squash-only merging with the PR title and body as
   > the commit message, so each `main` commit corresponds to one ticket.
   > Allowing merge commits or rebase would fragment that mapping. May I
   > apply these settings now? (yes / no)

3. **If yes, apply** (two commands — `gh repo edit` cannot set the squash
   commit defaults, so the REST API is used for that part):
   ```bash
   gh repo edit \
     --enable-squash-merge \
     --enable-merge-commit=false \
     --enable-rebase-merge=false

   gh api -X PATCH "repos/$OWNER/$REPO" \
     -f squash_merge_commit_title=PR_TITLE \
     -f squash_merge_commit_message=PR_BODY
   ```

4. **If no**, skip and warn the user that PDH-style PRs may not merge cleanly with their current settings; they can re-run this step later by hand.

**Without `gh`:** tell the user to set these in the repo UI — **Settings → General → Pull Requests**:
- Check **Allow squash merging** only; uncheck **Allow merge commits** and **Allow rebase merging**
- Under the squash-merge subsection, set **Default commit message → Pull request title and description**

### Step 8: Commit and Push Changes

Commit all new/changed files with a descriptive message and push to the default branch. The workflow file must be on the default branch for GitHub Actions to recognize it.

### Step 9: Verify Workflow Registration

Confirm the workflow file is recognized by GitHub. With gh, run `gh workflow list` and check that `coding-robot` appears. Without gh, tell the user to check the Actions tab.

### Step 10: End-to-End Verification

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

### Step 11: Optional — Offer devcontainer prebuild (compose-based only)

After verification succeeds, decide whether to offer the prebuild optimization, then let the user choose.

**When to offer:** the devcontainer is **compose-based** (`devcontainer.json` has `dockerComposeFile`, i.e. Type C, or Type B whose existing devcontainer is compose-based) **and** GHCR is usable. With a compose-based devcontainer, `devcontainers/ci` cannot use its registry cache, so the bot **rebuilds the whole image on every run** (~14 min/run). Prebuild publishes the image once on `.devcontainer/**` changes and the bot just pulls it.

**When to skip:** Dockerfile-based devcontainer (registry cache already works), or the user does not use GHCR. For Type A (update only), skip — this is a one-time install-time choice.

**What to do:** briefly tell the user the trade-off (eliminates the per-run full rebuild; a multi-minute image pull remains) and ask whether to set it up now. If yes:

```
Read and execute https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/setup-prebuild.md
```

If the user declines, mention they can run it later — `setup-prebuild.md` is a standalone, opt-in step.

---

## File URLs

| File | URL | Notes |
|------|-----|-------|
| `.github/workflows/coding-robot.yml` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot.yml` | |
| `.github/workflows/coding-robot-finalize.yml` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/workflows/coding-robot-finalize.yml` | Finalizes tickets when a bot PR is merged (PDH repos); harmless if unused |
| `.github/coding-robot/run-action.sh` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/run-action.sh` | `chmod +x` after download |
| `.github/coding-robot/system.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system.md` | shared rules |
| `.github/coding-robot/system-claude.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system-claude.md` | claude-specific |
| `.github/coding-robot/system-codex.md` | `https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/system-codex.md` | codex-specific |
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
