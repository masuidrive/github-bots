# Coding Robot — Self-Update Procedure

You are the update executor for an **installed Coding Robot**. The user
asked you to update the coding-robot files in **this repository (the
target)** to the latest version from upstream (`masuidrive/github-bots`).

> This file lives in upstream only. You read it at runtime from the URL
> the system prompt gave you; do **not** copy `UPDATE.md` into the target
> repository.

## Hard constraints (do not violate)

- **Do NOT touch project files**: `.devcontainer/`, `.claude/CLAUDE.md`,
  `scripts/dev/`, `product-brief.md`, `tickets/`, application source code,
  README, or anything outside the two managed directories below.
- **Do NOT change repository settings**: secrets, variables, PR merge
  settings, branch protection.
- **Do NOT push directly to `main`** or rewrite its history. All updates
  land via a normal PR on the branch `agent/coding-robot-update`.
- **Do NOT bundle this update with other work.** Self-update is exclusive.

## Managed directories (anything else is off-limits)

- `.github/workflows/` — only files whose name starts with `coding-robot`
- `.github/coding-robot/` — recursive (but skip `UPDATE.md` itself; that
  file lives upstream only)

## Procedure

1. **Create or refresh the working branch**:
   ```bash
   git fetch origin
   git checkout -B agent/coding-robot-update origin/main
   ```

2. **Discover the upstream file list** for the two managed directories
   (so newly-added files in upstream are picked up automatically):
   ```bash
   UPSTREAM_RAW="https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot"
   UPSTREAM_API="repos/masuidrive/github-bots/contents/coding-robot"

   # coding-robot workflows
   gh api "${UPSTREAM_API}/.github/workflows?ref=main" \
     --jq '.[] | select(.name | startswith("coding-robot")) | .path'

   # .github/coding-robot/ contents (top-level)
   gh api "${UPSTREAM_API}/.github/coding-robot?ref=main" \
     --jq '.[] | select(.name != "UPDATE.md") | "\(.path) \(.type)"'

   # recurse into any subdirectory (e.g. engines/)
   # for each entry of type "dir", call the API again with that path.
   ```

3. **Download each discovered file** from
   `${UPSTREAM_RAW}/<path relative to coding-robot/>` and overwrite the local
   file at the same relative path in the target repo. `mkdir -p` the parent
   directory if it does not exist yet. Skip `UPDATE.md`.

   After downloading, make `run-action.sh` executable:
   ```bash
   chmod +x .github/coding-robot/run-action.sh
   ```

4. **Remove local files that no longer exist in upstream** (handles
   renames like `system.md` → `system-claude.md` and any future deletions
   without leaving stale residue on the target).

   **Scope: only the two managed directories.** Never touch anything
   outside them. Within them:

   - `.github/workflows/`: only files whose name starts with
     `coding-robot` are managed; leave the user's own workflow files
     alone even if they live in the same directory.
   - `.github/coding-robot/`: the whole directory tree is managed. Skip
     `UPDATE.md` itself if it somehow exists locally (it should not, but
     never delete it just in case).

   Example logic — adapt to your shell, but preserve the scope rules:
   ```bash
   # build the upstream lists from step 2 into shell variables, e.g.
   #   UPSTREAM_WORKFLOWS=$'coding-robot.yml\ncoding-robot-finalize.yml'
   #   UPSTREAM_CR=$'run-action.sh\nsystem-claude.md\n...\nengines/_claude.sh\n...'

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
   ```

   If a deletion would touch any path outside these two directories,
   that is a bug — abort and report it rather than proceeding.

5. **Inspect the result and confirm nothing leaked outside the managed
   directories**:
   ```bash
   git status
   git diff origin/main..HEAD --stat
   # The diff MUST only touch .github/workflows/coding-robot*.yml and
   # .github/coding-robot/**. If it touches anything else, abort.
   ```

   If there are no changes (already up-to-date), report
   "already up-to-date" and stop without opening a PR.

6. **Commit and push the branch**:
   ```bash
   git add .github
   git commit -m "chore(coding-robot): update from upstream"
   git push -u origin agent/coding-robot-update
   ```

7. **Write the final report** at `/tmp/agent-result.md` summarizing the
   diff (which files changed, brief one-line description of each major
   change picked up from upstream commit messages if you can read them).
   Include PR metadata markers so the harness emits a one-click "Create
   Pull Request" link:

   ```
   {{{{{pull-request-title
   chore(coding-robot): update from upstream
   pull-request-title}}}}}

   {{{{{pull-request-body
   Sync the coding-robot files (workflows + .github/coding-robot/) from
   masuidrive/github-bots@main.

   ## What changed
   - <bullet summary, generated from git diff --stat + a brief read of
      the upstream commit log between the user's installed snapshot and HEAD>

   ## Verification
   - Auto-update via UPDATE.md. Nothing outside the managed directories
     was modified (see `git diff main..HEAD --stat`).

   pull-request-body}}}}}
   ```

8. **Self-check before posting**:
   - Did you modify ONLY `.github/workflows/coding-robot*.yml` and
     `.github/coding-robot/**`? (use `git diff main..HEAD --stat`)
   - Did every deletion (if any) target a file inside those two managed
     directories AND absent from the upstream list? No deletions outside
     scope, and none of upstream's current files were removed.
   - Did you avoid pushing to `main`?
   - Did you avoid touching secrets / variables / PR settings?
   - Is the final report in the user's language (per Output Language rule)?

If any of these failed, fix it before posting the comment.
