# Coding Robot — Self-Update Procedure

You are the update executor for an **installed Coding Robot**. The user
asked you to update the coding-robot files in **this repository (the
target)** to the latest version from upstream.

**Two upstreams are synced together in a single PR**, because coding-robot
now requires the PDH skill core (`.claude/skills/pdh-dev/`) and breaks if
that drifts:

- `masuidrive/github-bots` → coding-robot files (workflow + harness + prompts)
- `masuidrive/pdh` → PDH skill core that coding-robot delegates policy to
  (`commit cadence`, `review convergence`, `test-all triage`, etc.)

> This file lives in the github-bots upstream only. You read it at runtime
> from the URL the system prompt gave you; do **not** copy `UPDATE.md`
> into the target repository.

## Hard constraints (do not violate)

- **Do NOT touch project files** outside the managed paths below:
  `.devcontainer/`, `.claude/CLAUDE.md`, `scripts/dev/`, `product-brief.md`,
  `tickets/`, application source code, README, `.ticket-config.yaml`,
  `CLAUDE.md`, `AGENTS.md`, `scripts/test-all.sh`, etc.
  (`ticket.sh` IS managed — see below — because `coding-robot-finalize.yml`
  depends on its flags; but `.ticket-config.yaml` is project config, never touched.)
- **Do NOT change repository settings**: secrets, variables, PR merge
  settings, branch protection.
- **Do NOT push directly to `main`** or rewrite its history. All updates
  land via a normal PR on the branch `agent/coding-robot-update`.
- **Do NOT bundle this update with other work.** Self-update is exclusive.

## Managed paths (anything else is off-limits)

**From `masuidrive/github-bots` (coding-robot):**
- `.github/workflows/` — only files whose name starts with `coding-robot`
- `.github/coding-robot/` — recursive (but skip `UPDATE.md` itself; that
  file lives upstream only)

**From `masuidrive/pdh` (PDH skill core that coding-robot mandates):**
- `.claude/skills/pdh-dev/` — recursive (whole tree replaced from upstream)
- `.claude/skills/pdh-coding/` — recursive (referenced by pdh-dev workers)
- `docs/product-delivery-hierarchy.md` — single file (read by every PDH
  worker as background)

**From `masuidrive/ticket.sh` (PDH repos only):**
- `ticket.sh` — single file, refreshed **only if it already exists** in the
  repo (never created). `coding-robot-finalize.yml` calls
  `ticket.sh close --no-merge --closed-at …` on PR merge, so the bundled CLI
  must stay new enough to support those flags. `.ticket-config.yaml` is project
  config and is NOT touched.

Anything else from the `masuidrive/pdh` upstream (`templates/`,
`scripts/hookbus.js`, `skills/pdh-update/`, `skills/tmux-director/`,
`README.md`, `pdh-header.png`) is **out of scope** for this self-update —
those are user-installed via the PDH onboarding procedure and may be
customized. Do not touch them.

## Procedure

1. **Create or refresh the working branch**:
   ```bash
   git fetch origin
   git checkout -B agent/coding-robot-update origin/main
   ```

2. **Discover the upstream file list** for ALL managed paths (both
   upstreams). Newly-added files are picked up automatically:
   ```bash
   # coding-robot upstream
   CR_RAW="https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot"
   CR_API="repos/masuidrive/github-bots/contents/coding-robot"

   # coding-robot workflows
   gh api "${CR_API}/.github/workflows?ref=main" \
     --jq '.[] | select(.name | startswith("coding-robot")) | .path'

   # .github/coding-robot/ contents (top-level)
   gh api "${CR_API}/.github/coding-robot?ref=main" \
     --jq '.[] | select(.name != "UPDATE.md") | "\(.path) \(.type)"'

   # recurse into any subdirectory (e.g. engines/)
   # for each entry of type "dir", call the API again with that path.

   # pdh upstream
   PDH_RAW="https://raw.githubusercontent.com/masuidrive/pdh/refs/heads/main"
   PDH_API="repos/masuidrive/pdh/contents"

   # pdh-dev skill tree (recurse into subdirs)
   gh api "${PDH_API}/skills/pdh-dev?ref=main" --jq '.[] | "\(.path) \(.type)"'

   # pdh-coding skill tree (recurse into subdirs)
   gh api "${PDH_API}/skills/pdh-coding?ref=main" --jq '.[] | "\(.path) \(.type)"'

   # Single file: docs/product-delivery-hierarchy.md (no listing needed)

   # ticket.sh upstream (PDH repos only; single file, refresh only if present)
   TICKET_RAW="https://raw.githubusercontent.com/masuidrive/ticket.sh/refs/heads/main/ticket.sh"
   ```

3. **Download each discovered file** and overwrite the local file at the
   matching relative path. `mkdir -p` the parent directory if it does not
   exist yet.

   - From coding-robot upstream: `${CR_RAW}/<path relative to coding-robot/>`
     → target `<path>` (so `coding-robot/.github/coding-robot/run-action.sh`
     → `.github/coding-robot/run-action.sh`). Skip `UPDATE.md`.
   - From pdh upstream:
     - `${PDH_RAW}/skills/pdh-dev/<file>` → target `.claude/skills/pdh-dev/<file>`
     - `${PDH_RAW}/skills/pdh-coding/<file>` → target `.claude/skills/pdh-coding/<file>`
     - `${PDH_RAW}/docs/product-delivery-hierarchy.md` → target same path
   - From ticket.sh upstream — **only if `ticket.sh` already exists locally**
     (PDH repo). Do NOT create it where it is absent:
     `${TICKET_RAW}` → target `ticket.sh`.
   - No `Based on` footer sed substitution is required for any of these
     files (the pdh README §2 sed list does not include any of the
     in-scope paths).

   After downloading, make `run-action.sh` (and `ticket.sh` if refreshed)
   executable:
   ```bash
   chmod +x .github/coding-robot/run-action.sh
   [ -f ticket.sh ] && chmod +x ticket.sh
   ```

4. **Remove local files that no longer exist in upstream** (handles
   renames like `system.md` → `system-claude.md` and any future deletions
   without leaving stale residue on the target).

   **Scope: only the managed paths declared above.** Never touch anything
   outside them. Within them:

   - `.github/workflows/`: only files whose name starts with
     `coding-robot` are managed; leave the user's own workflow files
     alone even if they live in the same directory.
   - `.github/coding-robot/`: whole directory tree is managed. Skip
     `UPDATE.md` itself if it somehow exists locally (it should not, but
     never delete it just in case).
   - `.claude/skills/pdh-dev/`: whole directory tree is managed.
   - `.claude/skills/pdh-coding/`: whole directory tree is managed.
   - `docs/product-delivery-hierarchy.md`: single file only — never
     delete or sweep anything else under `docs/`.

   Example logic — adapt to your shell, but preserve the scope rules:
   ```bash
   # build the upstream lists from step 2 into shell variables, e.g.
   #   UPSTREAM_WORKFLOWS=$'coding-robot.yml\ncoding-robot-finalize.yml'
   #   UPSTREAM_CR=$'run-action.sh\nsystem-claude.md\n...\nengines/_claude.sh\n...'
   #   UPSTREAM_PDH_DEV=$'SKILL.md\n_flow.md\n_review.md\n...'
   #   UPSTREAM_PDH_CODING=$'SKILL.md\n...'

   # workflows: only coding-robot* files
   for f in .github/workflows/coding-robot*; do
     [ -e "$f" ] || continue
     name="$(basename "$f")"
     if ! grep -qxF "$name" <<<"$UPSTREAM_WORKFLOWS"; then
       git rm -- "$f"
     fi
   done

   # coding-robot/ tree
   while IFS= read -r f; do
     rel="${f#.github/coding-robot/}"
     [ "$rel" = "UPDATE.md" ] && continue
     if ! grep -qxF "$rel" <<<"$UPSTREAM_CR"; then
       git rm -- "$f"
     fi
   done < <(find .github/coding-robot -type f 2>/dev/null)

   # pdh-dev/ tree
   while IFS= read -r f; do
     rel="${f#.claude/skills/pdh-dev/}"
     if ! grep -qxF "$rel" <<<"$UPSTREAM_PDH_DEV"; then
       git rm -- "$f"
     fi
   done < <(find .claude/skills/pdh-dev -type f 2>/dev/null)

   # pdh-coding/ tree
   while IFS= read -r f; do
     rel="${f#.claude/skills/pdh-coding/}"
     if ! grep -qxF "$rel" <<<"$UPSTREAM_PDH_CODING"; then
       git rm -- "$f"
     fi
   done < <(find .claude/skills/pdh-coding -type f 2>/dev/null)

   # docs/product-delivery-hierarchy.md is a single file — no sweep needed.
   ```

   If a deletion would touch any path outside the managed paths,
   that is a bug — abort and report it rather than proceeding.

5. **Inspect the result and confirm nothing leaked outside the managed
   paths**:
   ```bash
   git status
   git diff origin/main..HEAD --stat
   # The diff MUST only touch:
   #   .github/workflows/coding-robot*.yml
   #   .github/coding-robot/**
   #   .claude/skills/pdh-dev/**
   #   .claude/skills/pdh-coding/**
   #   docs/product-delivery-hierarchy.md
   # If it touches anything else, abort.
   ```

   If there are no changes (already up-to-date), report
   "already up-to-date" and stop without opening a PR.

6. **Commit and push the branch**. Use two commits so reviewers can see
   which upstream each batch came from:
   ```bash
   # Commit 1: coding-robot
   git add .github
   git commit -m "chore(coding-robot): update from upstream masuidrive/github-bots"

   # Commit 2: PDH skill core (only if any pdh files changed)
   git add .claude/skills/pdh-dev .claude/skills/pdh-coding docs/product-delivery-hierarchy.md
   git commit -m "chore(pdh): update skill core from upstream masuidrive/pdh"

   git push -u origin agent/coding-robot-update
   ```
   If one side has no changes, skip that commit silently — do not create
   an empty commit.

7. **Write the final report** at `/tmp/agent-result.md` summarizing the
   diff (which files changed in each upstream, brief one-line description
   of each major change picked up from upstream commit messages if you
   can read them). Include PR metadata markers so the harness emits a
   one-click "Create Pull Request" link:

   ```
   {{{{{pull-request-title
   chore: update coding-robot and PDH skill core from upstream
   pull-request-title}}}}}

   {{{{{pull-request-body
   Sync coding-robot (workflows + .github/coding-robot/) from
   masuidrive/github-bots@main, and the PDH skill core
   (.claude/skills/pdh-dev/, .claude/skills/pdh-coding/,
   docs/product-delivery-hierarchy.md) from masuidrive/pdh@main.

   coding-robot now requires the PDH skill core, so the two are synced
   together to avoid drift between policy (in PDH) and orchestration
   (in coding-robot).

   ## What changed (coding-robot)
   - <bullet summary from masuidrive/github-bots commit log>

   ## What changed (PDH skill core)
   - <bullet summary from masuidrive/pdh commit log; or "no changes" if
     pdh upstream was already in sync>

   ## Verification
   - Auto-update via UPDATE.md. Nothing outside the managed paths was
     modified (see `git diff main..HEAD --stat`).

   pull-request-body}}}}}
   ```

8. **Self-check before posting**:
   - Did you modify ONLY paths inside the managed list?
     (`.github/workflows/coding-robot*.yml`, `.github/coding-robot/**`,
     `.claude/skills/pdh-dev/**`, `.claude/skills/pdh-coding/**`,
     `docs/product-delivery-hierarchy.md`)
   - Did every deletion (if any) target a file inside the managed paths
     AND absent from the corresponding upstream list? No deletions
     outside scope, and none of upstream's current files were removed.
   - Did you leave `templates/`, `ticket.sh`, `.ticket-config.yaml`,
     `CLAUDE.md`, `AGENTS.md`, `scripts/test-all.sh`, `scripts/hookbus.js`,
     `product-brief.md`, `tickets/`, application source code, and README
     untouched?
   - Did you avoid pushing to `main`?
   - Did you avoid touching secrets / variables / PR settings?
   - Is the final report in the user's language (per Output Language rule)?

If any of these failed, fix it before posting the comment.
