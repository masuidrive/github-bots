# coding-robot

🤖 An AI coding agent for GitHub Actions. Comment `:robot:` (or paste 🤖) on any Issue or PR and it branches, investigates, implements, tests, and reports back — optionally as a full PDH ticket-driven flow.

---

## Install (for an AI assistant)

You are an install executor. Follow the steps below to install coding-robot into the **current** repository, then hand off to [`setup.md`](setup.md) for the file mechanics. Always respond in the user's language.

> Prerequisite: be on the default branch (usually `main`), with a GitHub `origin` remote. `gh` authenticated (`gh auth status`) is strongly recommended — it lets you set the variable/secret and run the end-to-end test automatically. Without `gh`, fall back to the repo Settings UI (URLs below).

### Step 0 — Choose the engine (ask the user)

Ask the user, and wait for an answer:

> Which engine should Coding Robot use — **Claude Code** or **Codex**? (one must be chosen; there is no default)

Record it as `ENGINE` (`claude` or `codex`). It decides the variable and which **one** secret to set below. The choice persists for the repo and can be changed later by updating the variable.

### Step 1 — Set the engine variable (`gh`)

The workflow reads the `CODING_ROBOT_ENGINE` repository **variable** (required; the workflow fails fast if unset):

```bash
gh variable set CODING_ROBOT_ENGINE --body "<claude|codex>"   # the value chosen in Step 0
```

### Step 2 — Write the engine credential (`gh`)

Set **only the secret for the chosen engine.**

**If `claude`** — secret `CLAUDE_CODE_OAUTH_TOKEN`
`claude setup-token` requires interactive browser auth, so **the user** must run it — you cannot. Ask them to run it in a separate terminal and paste the token, then:

```bash
gh secret set CLAUDE_CODE_OAUTH_TOKEN     # paste the token from `claude setup-token`
```

**If `codex`** — secret `CODEX_AUTH_JSON` (ChatGPT plan) **or** `OPENAI_API_KEY` (API-key billing)
For the ChatGPT plan, the user runs `codex login` locally, then provides their auth file **as a single line** (a multi-line value breaks the workflow's env passing):

```bash
jq -c . ~/.codex/auth.json | gh secret set CODEX_AUTH_JSON
```

Or, for API-key billing:

```bash
gh secret set OPENAI_API_KEY              # the user's OpenAI API key
```

#### Step 2b — Offer to also set the other engine's credential

After the chosen engine's secret is in place, **ask the user**:

> You picked `<ENGINE>`. Do you also want to set the credential for the other engine now, so you can switch later just by changing `CODING_ROBOT_ENGINE`? (yes / no)

If **yes**, repeat Step 2 for the other engine's secret. If **no**, skip — they can add it later. Do not set it without asking.

> **No `gh`?** Set them in the repo UI — Settings → Secrets and variables → Actions (Variables tab for `CODING_ROBOT_ENGINE`, Secrets tab for the credential):
> `https://github.com/OWNER/REPO/settings/secrets/actions`
>
> **Credentials can also be set after install.** `run-action.sh` detects a missing/invalid credential at runtime and posts a comment with exact fix instructions, so a not-yet-set secret never fails silently.

### Step 3 — Configure PR merge settings (required for PDH PR flow)

PDH-style PRs expect **squash-only** merging with the **PR title + body** as the squash commit message, so each `main` commit aligns with one ticket. Allowing merge commits or rebase would fragment that mapping.

**Show current state, then ask:**

```bash
gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
gh api "repos/$OWNER/$REPO" --jq '{squash_merge_commit_title, squash_merge_commit_message}'
```

> The PDH PR flow needs squash-only merging with the PR title and body as the
> commit message. Allowing merge commits or rebase would break the
> commit-to-ticket alignment. May I apply these settings now? (yes / no)

**If yes** (two commands — `gh repo edit` cannot set the squash commit defaults):

```bash
gh repo edit \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false

gh api -X PATCH "repos/$OWNER/$REPO" \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY
```

**If no**, skip — warn that PDH-style PRs may not merge cleanly until the user enables the same settings later.

> **No `gh`?** Set them in the repo UI — Settings → General → Pull Requests:
> - Check **Allow squash merging** only; uncheck **Allow merge commits** + **Allow rebase merging**
> - Under squash merging, set **Default commit message → Pull request title and description**

### Step 4 — Install the bot files and verify

Now follow **[`setup.md`](setup.md)** for the rest: it detects the install type (update vs. new), downloads the workflow + `coding-robot-finalize.yml` + `run-action.sh` + `system*.md` + `_issue.md` / `_pr.md` / `_pdh.md` + engine scripts (and the devcontainer if needed), commits, and runs an **end-to-end test** by creating a `🤖` Issue. You already chose the engine in Step 0, so skip setup.md's engine-selection prompt and reuse `ENGINE`.

---

## Updating an installed bot

Once installed, the bot can update itself in place. Open an Issue or PR in the target repo and comment with the self-update intent — examples:

> 🤖 coding-robot をアップデートして
>
> 🤖 update yourself

The bot recognizes the intent (see `system.md` → **Self-update intent**) and follows [`UPDATE.md`](.github/coding-robot/UPDATE.md) here in upstream, which downloads the latest workflow + `coding-robot` files (only those two managed directories) into a branch `agent/coding-robot-update` and opens a PR. It never touches `.devcontainer/`, `.claude/CLAUDE.md`, project sources, or repo settings. Merge the PR (squash) and you are on the latest version.

> **First update from a pre-UPDATE.md install:** if you installed before this mechanism existed, the bot's old system prompt does not yet know about UPDATE.md. Run the first update by passing the URL explicitly: `🤖 https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/.github/coding-robot/UPDATE.md を読んで、bot を最新にしてください`. After that PR is merged, plain "🤖 update yourself" works.

---

## PDH (ticket-driven) mode — optional

If the repository root has a `product-brief.md` and a `tickets/` directory, the bot automatically loads `_pdh.md` and runs the full PDH flow: the bot acts as PM, spawns a Coding Engineer + independent reviewers, verifies the acceptance criteria, and offers a PR. With no `product-brief.md`/`tickets/`, the bot runs self-contained (no PDH).

To enable PDH, also install the templates and skills from [masuidrive/pdh](https://github.com/masuidrive/pdh): `product-brief.md`, `ticket.sh`, `.ticket-config.yaml`, `docs/product-delivery-hierarchy.md`, and `.claude/skills/pdh-dev` + `.claude/skills/pdh-coding`.

---

## Engines

| Engine | Secret | Notes |
|---|---|---|
| Claude Code | `CLAUDE_CODE_OAUTH_TOKEN` | obtained via `claude setup-token` |
| Codex | `CODEX_AUTH_JSON` **or** `OPENAI_API_KEY` | ChatGPT plan (one-line JSON) or API key |

The active engine is selected by the `CODING_ROBOT_ENGINE` repository variable (`claude` | `codex`). The variable is required — there is no default.

---

## File attachments (optional)

The bot downloads files attached to the triggering Issue/PR (in the body **or any comment**) so the agent can read them — images were already supported; non-image files (PDF, `.txt`, `.csv`, logs, etc.) are downloaded too. Each file is saved under `/tmp/issue-<N>-files/` and listed in the agent prompt with its local path.

**One caveat for private repositories.** GitHub serves file attachments (`https://github.com/user-attachments/files/...`) in a way that the Actions installation token (`secrets.GITHUB_TOKEN`) **cannot** access — it returns `404`. Unlike inline images, these URLs are not re-signed in the rendered `bodyHTML`, so there is no token-free path. To enable file-attachment downloads on a private repo, add a **classic Personal Access Token** with the `repo` scope as the secret `ATTACHMENTS_TOKEN`:

```bash
gh secret set ATTACHMENTS_TOKEN   # paste a classic PAT (repo scope)
```

> Create the PAT at `https://github.com/settings/tokens` (Tokens (classic) → `repo` scope). Fine-grained tokens are not guaranteed to work for the attachment endpoint.

`ATTACHMENTS_TOKEN` is **optional**. If it is unset, the download step logs a warning and skips (it never fails the run); on public repos the fallback `GITHUB_TOKEN` is usually sufficient. Image download is unaffected and needs no PAT.
