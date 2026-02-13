#!/bin/bash
set -e

# Function to post error comments
post_error_comment() {
  local error_message="$1"
  local workflow_url="https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"

  if [ -n "$PROGRESS_COMMENT_ID" ] && [ -n "$GITHUB_REPOSITORY" ] && [ -n "$ISSUE_NUMBER" ]; then
    echo "📝 Posting error comment..."
    gh api -X PATCH repos/$GITHUB_REPOSITORY/issues/comments/$PROGRESS_COMMENT_ID \
      -f body="## ❌ Error Occurred

$error_message

### 📋 Details
- **Workflow Run**: [View logs]($workflow_url)
- **Run ID**: $GITHUB_RUN_ID

---
🤖 [Claude Code Bot](https://github.com/masuidrive/github-bots/tree/main/coding-robot)" || true
  fi
}

# Handler for unexpected errors
handle_unexpected_error() {
  local exit_code=$?
  local line_number=$1
  if [ $exit_code -ne 0 ]; then
    echo "💥 Unexpected error at line $line_number (exit code: $exit_code)"
    post_error_comment "### 💥 Unexpected Error

An error occurred during script execution.

- **Exit Code**: $exit_code
- **Line**: $line_number

Please check the workflow logs for more details."
  fi
}

# Set error trap (enabled after PROGRESS_COMMENT_ID is set)
trap 'handle_unexpected_error $LINENO' ERR

echo "🤖 Claude Bot starting..."

# 現在のディレクトリを表示
echo "📁 Current directory: $(pwd)"
echo "📁 Contents:"
ls -la

# Gitリポジトリが現在のディレクトリにあるか確認
if [ ! -d ".git" ]; then
  echo "⚠️ .git directory not found in current directory"

  # 作業ディレクトリを探す
  if [ -d "/workspaces/review-apps/.git" ]; then
    cd /workspaces/review-apps
    echo "✅ Changed to /workspaces/review-apps"
  elif [ -d "/workspace/.git" ]; then
    cd /workspace
    echo "✅ Changed to /workspace"
  else
    echo "❌ Cannot find git repository"
    exit 1
  fi
fi

echo "📁 Working directory: $(pwd)"

# 環境変数チェック
if [ -z "$ISSUE_NUMBER" ] || [ -z "$GITHUB_REPOSITORY" ]; then
  echo "❌ Required environment variables are missing"
  echo "ISSUE_NUMBER: $ISSUE_NUMBER"
  echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
  exit 1
fi

echo "📋 Issue/PR: #$ISSUE_NUMBER"
echo "📦 Repository: $GITHUB_REPOSITORY"
echo "🎯 Event type: $EVENT_TYPE"

# Git 設定
git config --global --add safe.directory /workspaces/review-apps
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

# 最新の状態を取得
git fetch origin

# Issue/PR情報の取得
echo "📝 Fetching Issue/PR data..."
if [[ "$EVENT_TYPE" == "pull_request"* ]]; then
  # PR の場合
  PR_DATA=$(gh pr view $ISSUE_NUMBER \
    --json title,body,comments,headRefName \
    --repo $GITHUB_REPOSITORY)

  ISSUE_TITLE=$(echo "$PR_DATA" | jq -r '.title')
  ISSUE_BODY=$(echo "$PR_DATA" | jq -r '.body // ""')

  # PR の場合: head ブランチ名を取得
  BRANCH_NAME=$(echo "$PR_DATA" | jq -r '.headRefName')
  echo "📌 PR head branch: $BRANCH_NAME"

  git checkout "$BRANCH_NAME"
  git pull origin "$BRANCH_NAME" || true

  # PR diff取得
  PR_DIFF=$(gh pr diff $ISSUE_NUMBER --repo $GITHUB_REPOSITORY | head -1000 || echo "")

else
  # Issue の場合
  ISSUE_DATA=$(gh issue view $ISSUE_NUMBER \
    --json title,body,comments \
    --repo $GITHUB_REPOSITORY)

  ISSUE_TITLE=$(echo "$ISSUE_DATA" | jq -r '.title')
  ISSUE_BODY=$(echo "$ISSUE_DATA" | jq -r '.body // ""')

  # Issue の場合: 新しいブランチ名を作成
  BRANCH_NAME="claude-bot/issue-${ISSUE_NUMBER}"
  echo "📌 Issue branch: $BRANCH_NAME"

  if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    # ブランチが存在 → checkout
    git checkout "$BRANCH_NAME"
    git pull origin "$BRANCH_NAME" || true
  else
    # ブランチが存在しない → 作成
    git checkout -b "$BRANCH_NAME"
  fi

  PR_DIFF=""
fi

# REST API で全コメント取得（数値 ID 付き。COMMENT_ID とのマッチングに必要）
ALL_COMMENTS_JSON=$(gh api repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments --paginate \
  --jq '[.[] | {id: .id, login: .user.login, body: .body}]' 2>/dev/null || echo '[]')

# === コメントの構造化: トリガーコメント vs 過去ログ ===
# COMMENT_ID が設定されている場合、そのコメントがトリガー（＝ユーザの指示）
# それ以外のコメントは過去の会話ログとして参考情報扱い

if [ -n "$COMMENT_ID" ]; then
  # トリガーコメントの本文を直接取得（GitHub API、1回で body + login 両方取得）
  TRIGGER_DATA=$(gh api repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID 2>/dev/null || echo '{}')
  TRIGGER_COMMENT=$(echo "$TRIGGER_DATA" | jq -r '.body // ""')
  TRIGGER_AUTHOR=$(echo "$TRIGGER_DATA" | jq -r '.user.login // "unknown"')
  # /code や 🤖 トリガー文字列を除去
  USER_REQUEST=$(echo "$TRIGGER_COMMENT" | sed -E 's/\/(code|🤖)//gi; s/^[[:space:]]*//; s/[[:space:]]*$//')
  echo "📌 Trigger comment by $TRIGGER_AUTHOR (ID: $COMMENT_ID)"
else
  # COMMENT_ID がない場合（issues opened 等）: issue body 自体が指示
  USER_REQUEST=$(echo "$ISSUE_BODY" | sed -E 's/\/(code|🤖)//gi; s/^[[:space:]]*//; s/[[:space:]]*$//')
  TRIGGER_COMMENT=""
  TRIGGER_AUTHOR=""
  COMMENT_ID=""
fi

# 過去の会話ログ構築（トリガーコメントを除外）
# 直近10件はプロンプトにインライン、それより前は /tmp/conversation-history.md に書き出し
ALL_FILTERED=$(echo "$ALL_COMMENTS_JSON" | jq -r --arg comment_id "${COMMENT_ID:-0}" '
  [.[] | select(.id != ($comment_id | tonumber? // -1))] | .[-32:]' 2>/dev/null || echo '[]')

TOTAL_COMMENTS=$(echo "$ALL_FILTERED" | jq 'length')

if [ "$TOTAL_COMMENTS" -gt 10 ]; then
  # 古いコメントをファイルに書き出し
  OLDER_COUNT=$((TOTAL_COMMENTS - 10))
  echo "$ALL_FILTERED" | jq -r ".[0:$OLDER_COUNT][] | \"[\" + .login + \"] \" + .body" > /tmp/conversation-history.md
  echo "📄 Wrote $OLDER_COUNT older comments to /tmp/conversation-history.md"

  # 直近10件をインライン
  CONVERSATION_HISTORY=$(echo "$ALL_FILTERED" | jq -r '.[-10:][] | "[" + .login + "] " + .body')
  CONVERSATION_HISTORY_NOTE="(${OLDER_COUNT} older comments available in /tmp/conversation-history.md)

$CONVERSATION_HISTORY"
else
  CONVERSATION_HISTORY_NOTE=$(echo "$ALL_FILTERED" | jq -r '.[] | "[" + .login + "] " + .body' 2>/dev/null || echo "(no previous comments)")
fi

# main を merge
echo "🔀 Merging origin/main into $BRANCH_NAME..."
MERGE_OUTPUT=$(git merge origin/main --no-edit 2>&1) || MERGE_EXIT_CODE=$?
MERGE_EXIT_CODE=${MERGE_EXIT_CODE:-0}

CONFLICT_SECTION=""
if [ $MERGE_EXIT_CODE -ne 0 ]; then
  echo "⚠️ Merge conflict detected!"

  # conflict があれば、Claude に解決させる
  CONFLICT_FILES=$(git diff --name-only --diff-filter=U)

  CONFLICT_SECTION="

---

# 🚨 IMPORTANT: Git Merge Conflict Detected

**You MUST resolve the merge conflicts BEFORE starting the user's task.**

## Conflicted Files:
\`\`\`
$CONFLICT_FILES
\`\`\`

## Steps to Resolve:
1. Read each conflicted file
2. Understand both changes (current branch vs main)
3. Resolve conflicts by editing files (remove conflict markers <<<<<<, =======, >>>>>>>)
4. Stage resolved files: \`git add <file>\`
5. Commit the merge: \`git commit -m \"Merge main into $BRANCH_NAME\"\`
6. Verify: \`git status\` should show no conflicts

**After resolving conflicts, proceed with the user's original request.**
"
else
  echo "✅ Merge successful (no conflicts)"
fi

# 画像URLを抽出してダウンロード
echo "🖼️ Checking for attached images..."
IMAGE_DIR="/tmp/issue-${ISSUE_NUMBER}-images"
mkdir -p "$IMAGE_DIR"

# 元のMarkdownから画像URLを抽出（表示用）
ORIGINAL_IMAGE_URLS=$(echo "$ISSUE_BODY" | \
  grep -oE '(https?://[^)"\s]+\.(png|jpg|jpeg|gif|webp|svg))|(https?://github\.com/user-attachments/assets/[^)"\s]+)|(https?://user-images\.githubusercontent\.com/[^)"\s]+)' | \
  sort -u)

# GraphQL API を使って bodyHTML を取得（JWT付きの実際の画像URLを含む）
if [[ "$EVENT_TYPE" == "pull_request"* ]]; then
  BODY_HTML=$(gh api graphql -f query="
    query {
      repository(owner: \"$(echo $GITHUB_REPOSITORY | cut -d/ -f1)\", name: \"$(echo $GITHUB_REPOSITORY | cut -d/ -f2)\") {
        pullRequest(number: $ISSUE_NUMBER) {
          bodyHTML
        }
      }
    }
  " --jq '.data.repository.pullRequest.bodyHTML' 2>/dev/null || echo "")
else
  BODY_HTML=$(gh api graphql -f query="
    query {
      repository(owner: \"$(echo $GITHUB_REPOSITORY | cut -d/ -f1)\", name: \"$(echo $GITHUB_REPOSITORY | cut -d/ -f2)\") {
        issue(number: $ISSUE_NUMBER) {
          bodyHTML
        }
      }
    }
  " --jq '.data.repository.issue.bodyHTML' 2>/dev/null || echo "")
fi

# bodyHTML から画像URLを抽出（JWT付きのprivate-user-images URLと通常の画像URL）
# sed を使って href と src 属性から URL を抽出
DOWNLOAD_IMAGE_URLS=$(echo "$BODY_HTML" | \
  sed -n 's/.*\(href\|src\)="\([^"]*\)".*/\2/p' | \
  grep -E 'https?://(private-user-images\.githubusercontent\.com/[^[:space:]]+|[^[:space:]]+\.(png|jpg|jpeg|gif|webp|svg)(\?[^[:space:]]*)?|user-images\.githubusercontent\.com/[^[:space:]]+)' | \
  sort -u)

# 元のURLとダウンロードURLを配列化
IFS=$'\n' read -d '' -r -a ORIGINAL_URLS_ARRAY <<< "$ORIGINAL_IMAGE_URLS" || true
IFS=$'\n' read -d '' -r -a DOWNLOAD_URLS_ARRAY <<< "$DOWNLOAD_IMAGE_URLS" || true

IMAGE_COUNT=0
IMAGE_LIST=""
for i in "${!DOWNLOAD_URLS_ARRAY[@]}"; do
  download_url="${DOWNLOAD_URLS_ARRAY[$i]}"
  original_url="${ORIGINAL_URLS_ARRAY[$i]:-$download_url}"  # 元URLがなければダウンロードURLを使う

  if [ -n "$download_url" ]; then
    IMAGE_COUNT=$((IMAGE_COUNT + 1))
    # ファイル拡張子を抽出（URLパラメータの前の部分から）
    EXT=$(echo "$download_url" | sed -E 's/^.*\.([a-z]+)(\?.*)?$/\1/' | grep -E '^(png|jpg|jpeg|gif|webp|svg)$' || echo "png")
    FILENAME="image-${IMAGE_COUNT}.${EXT}"
    IMAGE_PATH="$IMAGE_DIR/$FILENAME"

    echo "  - Downloading: ${download_url:0:80}..."
    if curl -sL "$download_url" -o "$IMAGE_PATH" 2>/dev/null && [ -s "$IMAGE_PATH" ]; then
      # ファイルが正しくダウンロードされたか確認
      FILE_TYPE=$(file -b "$IMAGE_PATH" 2>/dev/null)
      if echo "$FILE_TYPE" | grep -qE "image|RIFF.*Web/P"; then
        IMAGE_LIST="$IMAGE_LIST
- $IMAGE_PATH (source: $original_url)"
        echo "    ✓ Saved to: $IMAGE_PATH ($FILE_TYPE)"
      else
        echo "    ✗ Not a valid image file: $FILE_TYPE"
        rm -f "$IMAGE_PATH"
        IMAGE_COUNT=$((IMAGE_COUNT - 1))
      fi
    else
      echo "    ✗ Failed to download"
      IMAGE_COUNT=$((IMAGE_COUNT - 1))
    fi
  fi
done

if [ $IMAGE_COUNT -gt 0 ]; then
  echo "✅ Downloaded $IMAGE_COUNT image(s)"
elif [ -n "$DOWNLOAD_IMAGE_URLS" ]; then
  echo "ℹ️ No images found in Issue/PR"
fi

# 画像セクションを構築
IMAGES_SECTION=""
if [ $IMAGE_COUNT -gt 0 ]; then
  IMAGES_SECTION="

---

# 📸 Attached Images

**IMPORTANT**: The user has attached $IMAGE_COUNT image(s) to this Issue/Pull Request.

## Image Files:
$IMAGE_LIST

## Instructions:
1. **Read each image** using the Read tool to understand the visual content
2. **Analyze the images** in the context of the user's request
3. **Reference the images** in your response when relevant

Use these images to better understand the user's requirements, bugs, design requests, or other visual information.
"
fi

# システムプロンプト読み込み
SYSTEM_PROMPT=$(cat .github/coding-robot/system.md | \
  sed "s|{DEVCONTAINER_CONFIG_PATH}|$DEVCONTAINER_CONFIG_PATH|g")

# ユーザプロンプト構築（システムプロンプトは --system-prompt で渡す）
USER_PROMPT="<current-request>
$USER_REQUEST
</current-request>

<context>
**Type**: $EVENT_TYPE
**Number**: #$ISSUE_NUMBER
**Title**: $ISSUE_TITLE

<description>
$ISSUE_BODY
</description>

<conversation-history>
$CONVERSATION_HISTORY_NOTE
</conversation-history>
</context>"

if [ -n "$PR_DIFF" ]; then
  USER_PROMPT="$USER_PROMPT

## PR Diff (first 1000 lines)
\`\`\`
$PR_DIFF
\`\`\`"
fi

USER_PROMPT="$USER_PROMPT
$CONFLICT_SECTION
$IMAGES_SECTION

---

# Your Working Branch

**Branch**: \`$BRANCH_NAME\`
**GitHub Comparison**: https://github.com/$GITHUB_REPOSITORY/compare/main...$BRANCH_NAME

You are working on this branch. All commits will be pushed here.
Users can view your changes by visiting the comparison page.

---

# Environment Variables Available
- ISSUE_NUMBER: $ISSUE_NUMBER
- GITHUB_REPOSITORY: $GITHUB_REPOSITORY
- BRANCH_NAME: $BRANCH_NAME
"

# プロンプトをファイルに保存
echo "$USER_PROMPT" > "/tmp/claude-prompt-$ISSUE_NUMBER.txt"

# 初期コメント投稿
echo "💬 Posting initial progress comment..."
PROGRESS_COMMENT_ID=$(gh api repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/comments \
  -f body="🤖 **作業中...**" --jq '.id')

echo "Progress comment ID: $PROGRESS_COMMENT_ID"

# CI環境での Claude CLI 認証設定
echo "🔑 Setting up Claude CLI authentication..."
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
  # CLAUDE_CODE_OAUTH_TOKEN はそのまま Claude CLI が認識する
  echo "✅ CLAUDE_CODE_OAUTH_TOKEN is set (long-lived token)"
else
  echo "❌ ERROR: CLAUDE_CODE_OAUTH_TOKEN is not set!"
  echo "Please set this secret in GitHub repository settings."
  post_error_comment "### 🔑 Authentication Error

\`CLAUDE_CODE_OAUTH_TOKEN\` secret is not configured.

**How to obtain a token:**

Run this command on your local machine:
\`\`\`bash
claude setup-token
\`\`\`

This will guide you through the authentication process and provide the token.

**How to set it up in GitHub:**
1. Go to [Repository Secrets Settings](https://github.com/$GITHUB_REPOSITORY/settings/secrets/actions)
2. Click \`New repository secret\`
3. Name: \`CLAUDE_CODE_OAUTH_TOKEN\`
4. Value: Paste the token from \`claude setup-token\`
5. Click \`Add secret\`

For more information, see the [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code).

---

**After setting the token, try commenting 🤖 \`:robot:\` on this thread again!**"
  exit 1
fi

# Claude CLI をバックグラウンドで実行（JSON streaming）
JSON_OUTPUT_FILE="/tmp/claude-output-$ISSUE_NUMBER.json"
PROGRESS_OUTPUT_FILE="/tmp/claude-progress-$ISSUE_NUMBER.txt"  # 進捗用（thinking + text）
RESULT_OUTPUT_FILE="/tmp/claude-result-$ISSUE_NUMBER.txt"      # 最終結果用（textのみ）
TASK_STATUS_FILE="/tmp/claude-tasks-$ISSUE_NUMBER.txt"         # タスク状態（常に最新）
TIMEOUT_VALUE=${CLAUDE_TIMEOUT:-5400}

echo "🚀 Starting Claude Code CLI (timeout: ${TIMEOUT_VALUE}s)..."

# =============================================================================
# Claude stream-json parsing
# =============================================================================
# 目的: Claude CLIの出力から最終結果のみを抽出
#
# 問題: Claudeは作業中に複数のtext blockを出力する
#   1. "画像を確認します" (途中のつぶやき)
#   2. [tool_use: Read実行]
#   3. "画像を分析しました" (さらなるつぶやき)
#   4. [tool_use: 複数のツール実行]
#   5. 実際の分析結果 ← これだけを最終結果として表示したい
#
# 解決策: content blockをindex別に管理し、message_stopで最後のtext blockのみ抽出
#
# Stream-JSON event構造 (Claude API仕様):
#   content_block_start (index: N, type: "text"|"tool_use")
#     content_block_delta (delta.type: "text_delta"|"input_json_delta")
#     content_block_delta ...
#   content_block_stop (index: N)
#   ...
#   message_stop ← 全メッセージ完了のシグナル
#
# 注意: Claude API仕様は将来変更される可能性があります
# =============================================================================

(
  > "$PROGRESS_OUTPUT_FILE"  # Initialize progress file
  > "$TASK_STATUS_FILE"       # Initialize task status file

  CURRENT_TOOL=""
  CURRENT_TOOL_INPUT=""
  CURRENT_BLOCK_INDEX=""
  CURRENT_BLOCK_TYPE=""
  MESSAGE_COUNTER=0  # Track which message/turn we're on to avoid block file overwrites
  BLOCKS_DIR="/tmp/claude-blocks-$ISSUE_NUMBER"
  mkdir -p "$BLOCKS_DIR"

  timeout $TIMEOUT_VALUE claude -p --dangerously-skip-permissions \
    --system-prompt "$SYSTEM_PROMPT" \
    --output-format stream-json --include-partial-messages --verbose \
    < "/tmp/claude-prompt-$ISSUE_NUMBER.txt" 2>&1 | \
  while IFS= read -r line; do
    echo "$line" >> "$JSON_OUTPUT_FILE"

    # -------------------------------------------------------------------------
    # ERROR DETECTION: Detect Claude API errors in streaming response
    # -------------------------------------------------------------------------
    # Format: event: error
    #         data: {"type": "error", "error": {"type": "...", "message": "..."}}
    ERROR_EVENT=$(echo "$line" | jq -r 'select(.type=="error") | .error' 2>/dev/null)
    if [ -n "$ERROR_EVENT" ] && [ "$ERROR_EVENT" != "null" ]; then
      ERROR_TYPE=$(echo "$ERROR_EVENT" | jq -r '.type // "unknown"')
      ERROR_MESSAGE=$(echo "$ERROR_EVENT" | jq -r '.message // "Unknown error"')

      echo "❌ Claude API Error detected during streaming:" >&2
      echo "   Type: $ERROR_TYPE" >&2
      echo "   Message: $ERROR_MESSAGE" >&2

      # Save error details for later reporting
      cat > "/tmp/claude-error-$ISSUE_NUMBER.json" << EOF
{
  "error_type": "$ERROR_TYPE",
  "error_message": "$ERROR_MESSAGE",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    fi

    # -------------------------------------------------------------------------
    # content_block_start: 新しいcontent block（text または tool_use）の開始を検出
    # -------------------------------------------------------------------------
    # 目的: 各blockをindex別に管理し、typeを記録する
    # JSON: {"type":"stream_event","event":{"type":"content_block_start","index":N,"content_block":{"type":"text"|"tool_use"}}}
    BLOCK_START=$(echo "$line" | jq -r 'select(.type=="stream_event" and .event.type=="content_block_start") | .event' 2>/dev/null)
    if [ -n "$BLOCK_START" ] && [ "$BLOCK_START" != "null" ]; then
      CURRENT_BLOCK_INDEX=$(echo "$BLOCK_START" | jq -r '.index')
      CURRENT_BLOCK_TYPE=$(echo "$BLOCK_START" | jq -r '.content_block.type')

      echo "DEBUG: content_block_start - index=$CURRENT_BLOCK_INDEX, type=$CURRENT_BLOCK_TYPE" >&2

      # 各blockを個別ファイルに保存（メッセージ番号を含めて上書きを防ぐ）
      > "$BLOCKS_DIR/block-m$MESSAGE_COUNTER-$CURRENT_BLOCK_INDEX.txt"
      echo "$CURRENT_BLOCK_TYPE" > "$BLOCKS_DIR/block-m$MESSAGE_COUNTER-$CURRENT_BLOCK_INDEX.type"

      # For tool_use blocks, extract tool name
      if [ "$CURRENT_BLOCK_TYPE" = "tool_use" ]; then
        TOOL_NAME=$(echo "$BLOCK_START" | jq -r '.content_block.name')
        CURRENT_TOOL="$TOOL_NAME"
        CURRENT_TOOL_INPUT=""
      fi
    fi

    # Accumulate tool input JSON
    if [ -n "$CURRENT_TOOL" ]; then
      INPUT_DELTA=$(echo "$line" | jq -r 'select(.type=="stream_event" and .event.type=="content_block_delta" and .event.delta.type=="input_json_delta") | .event.delta.partial_json' 2>/dev/null)
      if [ -n "$INPUT_DELTA" ] && [ "$INPUT_DELTA" != "null" ]; then
        CURRENT_TOOL_INPUT="${CURRENT_TOOL_INPUT}${INPUT_DELTA}"
      fi
    fi

    # Detect content_block_stop
    BLOCK_STOP_INDEX=$(echo "$line" | jq -r 'select(.type=="stream_event" and .event.type=="content_block_stop") | .event.index' 2>/dev/null)
    if [ -n "$BLOCK_STOP_INDEX" ] && [ "$BLOCK_STOP_INDEX" != "null" ]; then
      # Handle tools
      if [ -n "$CURRENT_TOOL" ]; then
        echo "DEBUG: Tool completed: $CURRENT_TOOL" >&2

        # Add newline before tool message if file doesn't end with one
        if [ -s "$PROGRESS_OUTPUT_FILE" ]; then
          LAST_CHAR=$(tail -c 1 "$PROGRESS_OUTPUT_FILE" 2>/dev/null)
          if [ -n "$LAST_CHAR" ] && [ "$LAST_CHAR" != $'\n' ]; then
            echo "" >> "$PROGRESS_OUTPUT_FILE"
          fi
        fi

        # Display tool execution details in progress
        case "$CURRENT_TOOL" in
          Bash)
            DESCRIPTION=$(echo "$CURRENT_TOOL_INPUT" | jq -r '.description // empty' 2>/dev/null)
            if [ -n "$DESCRIPTION" ]; then
              printf "🔧 [Bash: %s]\n" "$DESCRIPTION" >> "$PROGRESS_OUTPUT_FILE"
            else
              printf "🔧 [Bash実行中...]\n" >> "$PROGRESS_OUTPUT_FILE"
            fi
            ;;
          Read)
            FILE_PATH=$(echo "$CURRENT_TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)
            if [ -n "$FILE_PATH" ]; then
              printf "🔧 [Read: %s]\n" "$FILE_PATH" >> "$PROGRESS_OUTPUT_FILE"
            else
              printf "🔧 [Read実行中...]\n" >> "$PROGRESS_OUTPUT_FILE"
            fi
            ;;
          Write)
            FILE_PATH=$(echo "$CURRENT_TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)
            if [ -n "$FILE_PATH" ]; then
              printf "🔧 [Write: %s]\n" "$FILE_PATH" >> "$PROGRESS_OUTPUT_FILE"
            else
              printf "🔧 [Write実行中...]\n" >> "$PROGRESS_OUTPUT_FILE"
            fi
            ;;
          Edit)
            FILE_PATH=$(echo "$CURRENT_TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)
            if [ -n "$FILE_PATH" ]; then
              printf "🔧 [Edit: %s]\n" "$FILE_PATH" >> "$PROGRESS_OUTPUT_FILE"
            else
              printf "🔧 [Edit実行中...]\n" >> "$PROGRESS_OUTPUT_FILE"
            fi
            ;;
          Glob)
            PATTERN=$(echo "$CURRENT_TOOL_INPUT" | jq -r '.pattern // empty' 2>/dev/null)
            if [ -n "$PATTERN" ]; then
              printf "🔧 [Glob: %s]\n" "$PATTERN" >> "$PROGRESS_OUTPUT_FILE"
            else
              printf "🔧 [Glob実行中...]\n" >> "$PROGRESS_OUTPUT_FILE"
            fi
            ;;
          Grep)
            PATTERN=$(echo "$CURRENT_TOOL_INPUT" | jq -r '.pattern // empty' 2>/dev/null)
            if [ -n "$PATTERN" ]; then
              printf "🔧 [Grep: %s]\n" "$PATTERN" >> "$PROGRESS_OUTPUT_FILE"
            else
              printf "🔧 [Grep実行中...]\n" >> "$PROGRESS_OUTPUT_FILE"
            fi
            ;;
          TodoWrite|TaskCreate|TaskUpdate)
            echo "DEBUG: Processing task tool: $CURRENT_TOOL" >&2
            TASKS=$(echo "$CURRENT_TOOL_INPUT" | jq -r '.todos[]? // .subject? // empty' 2>/dev/null)
            if [ -n "$TASKS" ]; then
              echo "DEBUG: Found tasks, updating TASK_STATUS_FILE" >&2
              > "$TASK_STATUS_FILE"
              echo "$CURRENT_TOOL_INPUT" | jq -r '.todos[]? | "  \(if .status == "completed" then "✅" elif .status == "in_progress" then "🔄" else "◻️" end) \(.content // .subject)"' 2>/dev/null > "$TASK_STATUS_FILE" || true
              echo "DEBUG: TASK_STATUS_FILE content:" >&2
              cat "$TASK_STATUS_FILE" >&2
            else
              echo "DEBUG: No tasks found in tool input" >&2
            fi
            ;;
        esac
        CURRENT_TOOL=""
        CURRENT_TOOL_INPUT=""
      fi

      CURRENT_BLOCK_INDEX=""
      CURRENT_BLOCK_TYPE=""
    fi

    # Extract thinking_delta (progress only)
    THINKING=$(echo "$line" | jq -r 'select(.type=="stream_event" and .event.type=="content_block_delta" and .event.delta.type=="thinking_delta") | .event.delta.thinking' 2>/dev/null)
    if [ -n "$THINKING" ] && [ "$THINKING" != "null" ]; then
      printf "%s" "$THINKING" >> "$PROGRESS_OUTPUT_FILE"
    fi

    # -------------------------------------------------------------------------
    # text_delta: テキスト出力の増分
    # -------------------------------------------------------------------------
    # 目的: 進捗ファイルには全て保存、各blockファイルには該当indexのみ保存
    # JSON: {"type":"stream_event","event":{"type":"content_block_delta","index":N,"delta":{"type":"text_delta","text":"..."}}}
    TEXT_DELTA=$(echo "$line" | jq -r 'select(.type=="stream_event" and .event.type=="content_block_delta" and .event.delta.type=="text_delta") | .event' 2>/dev/null)
    if [ -n "$TEXT_DELTA" ] && [ "$TEXT_DELTA" != "null" ]; then
      TEXT=$(echo "$TEXT_DELTA" | jq -r '.delta.text')
      BLOCK_IDX=$(echo "$TEXT_DELTA" | jq -r '.index')

      # 進捗ファイルには全てのtext（途中のつぶやきも含む）を保存
      printf "%s" "$TEXT" >> "$PROGRESS_OUTPUT_FILE"

      # 各blockファイルにindex別に保存（後で最後のblockのみ抽出）
      if [ -n "$BLOCK_IDX" ] && [ "$BLOCK_IDX" != "null" ]; then
        printf "%s" "$TEXT" >> "$BLOCKS_DIR/block-m$MESSAGE_COUNTER-$BLOCK_IDX.txt"
      fi
    fi

    # -------------------------------------------------------------------------
    # message_stop: メッセージターン完了シグナル
    # -------------------------------------------------------------------------
    # 目的: MESSAGE_COUNTERをインクリメントして次のターンのblock ID衝突を防ぐ
    # JSON: {"type":"stream_event","event":{"type":"message_stop"}}
    MESSAGE_STOP=$(echo "$line" | jq -r 'select(.type=="stream_event" and .event.type=="message_stop") | .type' 2>/dev/null)
    if [ -n "$MESSAGE_STOP" ] && [ "$MESSAGE_STOP" != "null" ]; then
      MESSAGE_COUNTER=$((MESSAGE_COUNTER + 1))
      echo "DEBUG: message_stop detected, incremented MESSAGE_COUNTER to $MESSAGE_COUNTER" >&2
    fi
  done
) &
CLAUDE_PID=$!

echo "Claude PID: $CLAUDE_PID"

# GitHub Actions URL を取得
ACTIONS_URL="https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"

# 開始時刻を記録
START_TIME=$(date +%s)

# 進捗を定期的に更新（10秒ごと）
UPDATE_COUNT=0
while kill -0 $CLAUDE_PID 2>/dev/null; do
  sleep 10
  UPDATE_COUNT=$((UPDATE_COUNT + 1))

  # 経過時間を計算（MM:SS形式）
  CURRENT_TIME=$(date +%s)
  ELAPSED_SECONDS=$((CURRENT_TIME - START_TIME))
  ELAPSED_MINUTES=$((ELAPSED_SECONDS / 60))
  ELAPSED_SECS=$((ELAPSED_SECONDS % 60))
  ELAPSED_TIME=$(printf "%d:%02d" $ELAPSED_MINUTES $ELAPSED_SECS)

  # 出力の最後の部分を取得（最大2000文字）
  CURRENT_OUTPUT=$(tail -c 2000 "$PROGRESS_OUTPUT_FILE" 2>/dev/null || echo "（出力待機中...）")

  # タスク状態を取得
  TASK_STATUS=""
  if [ -s "$TASK_STATUS_FILE" ]; then
    TASK_STATUS=$(cat "$TASK_STATUS_FILE")
  fi

  # GitHub Actionsログに進捗の最後20行を出力
  echo "========== Claude Progress (last 20 lines) =========="
  tail -20 "$PROGRESS_OUTPUT_FILE" 2>/dev/null || echo "（出力待機中...）"
  echo "====================================================="

  # コメントを更新（タスク状態はcode blockの外）
  echo "📝 Updating progress comment (update $UPDATE_COUNT, elapsed: $ELAPSED_TIME)..."

  # Build comment body
  COMMENT_BODY="🤖 **作業中...** ($ELAPSED_TIME)"

  # Add plan summary if exists (1-3 lines explaining the approach)
  PLAN_SUMMARY_FILE="/tmp/claude-plan-summary-$ISSUE_NUMBER.txt"
  if [ -f "$PLAN_SUMMARY_FILE" ]; then
    PLAN_SUMMARY=$(cat "$PLAN_SUMMARY_FILE")
    if [ -n "$PLAN_SUMMARY" ]; then
      COMMENT_BODY="${COMMENT_BODY}

${PLAN_SUMMARY}"
    fi
  fi

  # Add task status if exists (outside code block)
  if [ -n "$TASK_STATUS" ]; then
    COMMENT_BODY="${COMMENT_BODY}

${TASK_STATUS}"
  fi

  # Add output in code block
  COMMENT_BODY="${COMMENT_BODY}

~~~~~~~~~
${CURRENT_OUTPUT}
~~~~~~~~~

🔗 [View job details]($ACTIONS_URL)"

  gh api -X PATCH repos/$GITHUB_REPOSITORY/issues/comments/$PROGRESS_COMMENT_ID \
    -f body="$COMMENT_BODY" || echo "Warning: Failed to update comment"
done

# 完了後、最終結果を投稿
wait $CLAUDE_PID
CLAUDE_EXIT_CODE=$?

echo "Claude finished with exit code: $CLAUDE_EXIT_CODE"

# 最終結果の抽出
# 優先順位: /tmp/ccbot-result.md > 最後のtext block
CCBOT_RESULT_FILE="/tmp/ccbot-result.md"

if [ -f "$CCBOT_RESULT_FILE" ]; then
  echo "✅ Found /tmp/ccbot-result.md - using it as final result"
  cat "$CCBOT_RESULT_FILE" > "$RESULT_OUTPUT_FILE"
else
  echo "⚠️  /tmp/ccbot-result.md not found - falling back to last text block extraction"

  # 全てのターンから最後のtext blockを抽出
  # 複数ターン（メッセージのやり取り）が発生するため、全block-m*-*.txtから最新を探す
  BLOCKS_DIR="/tmp/claude-blocks-$ISSUE_NUMBER"
  if [ -d "$BLOCKS_DIR" ]; then
    echo "Extracting last text block from all message turns..."
    LAST_TEXT_BLOCK=""
    LAST_MESSAGE_NUM=-1
    LAST_INDEX=-1

    # block-mN-I.txt 形式のファイルを全て走査（N=メッセージ番号, I=ブロックインデックス）
    for block_file in "$BLOCKS_DIR"/block-m*-*.txt; do
      if [ -f "$block_file" ]; then
        # ファイル名からメッセージ番号とインデックスを抽出: block-m2-0.txt -> MSG=2, IDX=0
        BASENAME=$(basename "$block_file" .txt)
        MSG_NUM=$(echo "$BASENAME" | sed 's/block-m\([0-9]*\)-.*/\1/')
        BLOCK_IDX=$(echo "$BASENAME" | sed 's/block-m[0-9]*-\([0-9]*\)/\1/')
        TYPE_FILE="$BLOCKS_DIR/block-m$MSG_NUM-$BLOCK_IDX.type"

        if [ -f "$TYPE_FILE" ]; then
          BLOCK_TYPE=$(cat "$TYPE_FILE")
          echo "  Found block-m$MSG_NUM-$BLOCK_IDX: type=$BLOCK_TYPE"

          if [ "$BLOCK_TYPE" = "text" ]; then
            # より新しいメッセージ、または同じメッセージでより大きいインデックスなら更新
            if [ "$MSG_NUM" -gt "$LAST_MESSAGE_NUM" ] || \
               ([ "$MSG_NUM" -eq "$LAST_MESSAGE_NUM" ] && [ "$BLOCK_IDX" -gt "$LAST_INDEX" ]); then
              LAST_TEXT_BLOCK="$block_file"
              LAST_MESSAGE_NUM=$MSG_NUM
              LAST_INDEX=$BLOCK_IDX
              echo "    -> Updated LAST_TEXT_BLOCK to block-m$MSG_NUM-$BLOCK_IDX"
            fi
          fi
        fi
      fi
    done

    if [ -n "$LAST_TEXT_BLOCK" ] && [ -f "$LAST_TEXT_BLOCK" ]; then
      echo "Writing last text block ($(basename "$LAST_TEXT_BLOCK")) to RESULT_OUTPUT_FILE"
      cat "$LAST_TEXT_BLOCK" > "$RESULT_OUTPUT_FILE"
    else
      echo "WARNING: No text blocks found!"
    fi
  fi
fi

# 最終結果を投稿（text outputのみ、thinkingは除外）
CLAUDE_OUTPUT=$(cat "$RESULT_OUTPUT_FILE")

if [ $CLAUDE_EXIT_CODE -eq 0 ]; then
  echo "✅ Task completed successfully"

  # 成功: 👀 リアクションを削除してから 👍 を追加
  REACTIONS_URL=""
  DELETE_URL_PREFIX=""

  if [ -n "$COMMENT_ID" ]; then
    # コメントへの返信の場合: コメントのリアクションを操作
    if [ "$EVENT_TYPE" = "issue_comment" ]; then
      REACTIONS_URL="repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID/reactions"
      DELETE_URL_PREFIX="repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID/reactions"
    elif [ "$EVENT_TYPE" = "pull_request_review_comment" ]; then
      REACTIONS_URL="repos/$GITHUB_REPOSITORY/pulls/comments/$COMMENT_ID/reactions"
      DELETE_URL_PREFIX="repos/$GITHUB_REPOSITORY/pulls/comments/$COMMENT_ID/reactions"
    elif [ "$EVENT_TYPE" = "pull_request_review" ]; then
      REACTIONS_URL="repos/$GITHUB_REPOSITORY/pulls/comments/$COMMENT_ID/reactions"
      DELETE_URL_PREFIX="repos/$GITHUB_REPOSITORY/pulls/comments/$COMMENT_ID/reactions"
    fi
  else
    # 新規 Issue/PR の場合: Issue/PR 自体のリアクションを操作
    if [[ "$EVENT_TYPE" == "issues" ]]; then
      REACTIONS_URL="repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/reactions"
      DELETE_URL_PREFIX="repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/reactions"
    elif [[ "$EVENT_TYPE" == "pull_request"* ]]; then
      REACTIONS_URL="repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/reactions"
      DELETE_URL_PREFIX="repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/reactions"
    fi
  fi

  if [ -n "$REACTIONS_URL" ]; then
    # 👀 リアクションを削除
    echo "Removing 👀 reaction from $REACTIONS_URL..."
    REACTIONS=$(gh api "$REACTIONS_URL" 2>/dev/null || echo "[]")
    echo "$REACTIONS" | jq -r '.[] | select(.content == "eyes") | .id' | while read REACTION_ID; do
      if [ -n "$REACTION_ID" ]; then
        echo "  Deleting reaction ID: $REACTION_ID"
        gh api -X DELETE "$DELETE_URL_PREFIX/$REACTION_ID" 2>/dev/null || echo "  Warning: Failed to delete reaction"
      fi
    done

    # 👍 リアクションを追加
    echo "Adding 👍 reaction..."
    gh api -X POST "$REACTIONS_URL" \
      -f content="+1" || echo "Warning: Failed to add reaction"
  fi

  # PR用のタイトルと本文をパース
  # /tmp/ccbot-result.mdから{{{{{pull-request-*...}}}}}を抽出
  PR_TITLE_RAW=""
  PR_BODY_RAW=""

  if [ -f "$CCBOT_RESULT_FILE" ]; then
    # Extract pull-request-title block (between {{{{{pull-request-title and pull-request-title}}}}})
    PR_TITLE_RAW=$(sed -n '/{{{{{pull-request-title/,/pull-request-title}}}}}/p' "$CCBOT_RESULT_FILE" | sed '1d;$d')
    # Extract pull-request-body block
    PR_BODY_RAW=$(sed -n '/{{{{{pull-request-body/,/pull-request-body}}}}}/p' "$CCBOT_RESULT_FILE" | sed '1d;$d')
  fi

  # Create PR link only if both title and body are provided
  PR_LINK=""
  if [ -n "$PR_TITLE_RAW" ] && [ -n "$PR_BODY_RAW" ]; then
    # URL encode using jq
    PR_TITLE_ENCODED=$(printf "%s" "$PR_TITLE_RAW" | jq -sRr @uri)
    PR_BODY_ENCODED=$(printf "%s" "$PR_BODY_RAW" | jq -sRr @uri)
    PR_LINK=" | 📋 [Create Pull Request](https://github.com/$GITHUB_REPOSITORY/compare/main...$BRANCH_NAME?expand=1&title=$PR_TITLE_ENCODED&body=$PR_BODY_ENCODED)"
    echo "✅ PR metadata found - Create PR link will be included"
  else
    echo "ℹ️  No PR metadata found - Create PR link will be omitted"
  fi

  # コメント投稿用の出力を準備（PR metadataマーカーを削除）
  CLAUDE_OUTPUT_CLEAN=$(echo "$CLAUDE_OUTPUT" | sed '/{{{{{pull-request-title/,/pull-request-title}}}}}/d' | sed '/{{{{{pull-request-body/,/pull-request-body}}}}}/d')

  # Remove trailing --- and empty lines to prevent duplication
  CLAUDE_OUTPUT_CLEAN=$(echo "$CLAUDE_OUTPUT_CLEAN" | \
    awk '{lines[NR]=$0} END {
      # Find last non-empty, non-separator line
      for(i=NR; i>=1; i--) {
        if(lines[i] !~ /^(---|[[:space:]]*)$/) {
          last=i; break
        }
      }
      # Print up to last meaningful line
      for(i=1; i<=last; i++) print lines[i]
    }')

  # 最終結果を投稿（ブランチ情報付き）
  gh api -X PATCH repos/$GITHUB_REPOSITORY/issues/comments/$PROGRESS_COMMENT_ID \
    -f body="$CLAUDE_OUTPUT_CLEAN

---

🌿 Branch: \`$BRANCH_NAME\`
📝 [View changes](https://github.com/$GITHUB_REPOSITORY/compare/main...$BRANCH_NAME)$PR_LINK"
else
  echo "❌ Task failed with exit code $CLAUDE_EXIT_CODE"

  # =========================================================================
  # ERROR REPORTING: Build detailed error message based on error type
  # =========================================================================
  ERROR_DETAILS=""
  ERROR_FILE="/tmp/claude-error-$ISSUE_NUMBER.json"

  # Priority 1: Authentication errors (most critical)
  if grep -qi "authentication\|unauthorized\|invalid.*api.*key\|CLAUDE_CODE_OAUTH_TOKEN" "$JSON_OUTPUT_FILE" "$PROGRESS_OUTPUT_FILE" 2>/dev/null; then
    ERROR_DETAILS="## 🔐 Authentication Error

Claude Bot failed to authenticate with Claude API.

**Common causes:**
- \`CLAUDE_CODE_OAUTH_TOKEN\` secret is not set in repository settings
- Token is expired or invalid
- Token doesn't have required permissions

**How to fix:**

1. **Check if secret exists:**
   - Go to: [Repository Settings → Secrets](https://github.com/$GITHUB_REPOSITORY/settings/secrets/actions)
   - Verify \`CLAUDE_CODE_OAUTH_TOKEN\` is listed

2. **Generate new token:**
   - Visit: https://claude.ai/
   - Login and generate a new OAuth token
   - Copy the token value

3. **Update GitHub Secret:**
   - Go to: https://github.com/$GITHUB_REPOSITORY/settings/secrets/actions
   - Click on \`CLAUDE_CODE_OAUTH_TOKEN\` and update with new token
   - Or add it if it doesn't exist

4. **Re-run this workflow:**
   - Close and reopen this issue with 🤖, or
   - Comment \`:robot:\` to retry"

  # Priority 2: Claude API errors (detected during streaming)
  elif [ -f "$ERROR_FILE" ]; then
    ERROR_TYPE=$(jq -r '.error_type' "$ERROR_FILE" 2>/dev/null || echo "unknown")
    ERROR_MESSAGE=$(jq -r '.error_message' "$ERROR_FILE" 2>/dev/null || echo "Unknown error")

    case "$ERROR_TYPE" in
      authentication_error)
        ERROR_DETAILS="## 🔐 Authentication Error

**Error Type:** \`authentication_error\`

**Error Message:**
\`\`\`
$ERROR_MESSAGE
\`\`\`

Your API key is invalid or expired. See the authentication fix steps above."
        ;;

      overloaded_error)
        ERROR_DETAILS="## 🚨 API Overloaded

**Error Type:** \`overloaded_error\`

**Error Message:**
\`\`\`
$ERROR_MESSAGE
\`\`\`

The Claude API is temporarily overloaded due to high traffic.

**What to do:**
- ⏳ Wait 5-10 minutes and retry
- 🔄 Comment \`:robot:\` on this issue to retry
- This is temporary and will resolve automatically"
        ;;

      rate_limit_error)
        ERROR_DETAILS="## ⏱️ Rate Limit Exceeded

**Error Type:** \`rate_limit_error\`

**Error Message:**
\`\`\`
$ERROR_MESSAGE
\`\`\`

Your account has hit the API rate limit.

**What to do:**
- ⏳ Wait a few minutes before retrying
- 📊 Check your API usage at https://console.anthropic.com/
- Consider spreading out requests over time"
        ;;

      invalid_request_error)
        ERROR_DETAILS="## ❌ Invalid Request

**Error Type:** \`invalid_request_error\`

**Error Message:**
\`\`\`
$ERROR_MESSAGE
\`\`\`

There's an issue with the request format or content.

**Possible causes:**
- Request size too large (max 32MB)
- Invalid parameters
- Malformed input

**What to do:**
- Simplify your request
- Break down large tasks into smaller steps
- Check the error message for specific details"
        ;;

      *)
        ERROR_DETAILS="## 🚨 Claude API Error

**Error Type:** \`$ERROR_TYPE\`

**Error Message:**
\`\`\`
$ERROR_MESSAGE
\`\`\`

An error occurred while communicating with Claude API."
        ;;
    esac

  # Priority 3: Timeout error (exit code 124)
  elif [ $CLAUDE_EXIT_CODE -eq 124 ]; then
    TIMEOUT_MINUTES=$((TIMEOUT_VALUE / 60))
    ERROR_DETAILS="## ⏱️ Timeout Error

Claude Bot exceeded the timeout limit of **${TIMEOUT_VALUE} seconds** (${TIMEOUT_MINUTES} minutes).

**Possible causes:**
- Task is too complex or time-consuming
- Bot got stuck in a loop
- Waiting for external resource that never responds
- Large file processing

**Suggested actions:**

1. **Break down the task** into smaller, focused steps
2. **Increase timeout** in \`.github/workflows/claude-bot.yml\`:
   \`\`\`yaml
   env: |
     CLAUDE_TIMEOUT=7200  # Increase to 2 hours (7200 seconds)
   \`\`\`
3. **Simplify requirements** or provide more specific instructions
4. **Check for blocking operations** (e.g., waiting for user input)
5. **Reduce scope** - focus on one thing at a time"

  # Priority 4: Generic execution error
  else
    # Extract last meaningful output for context
    LAST_OUTPUT=$(tail -n 100 "$PROGRESS_OUTPUT_FILE" 2>/dev/null | grep -v '^\s*$' | tail -20)

    ERROR_DETAILS="## ❌ Execution Error

Claude Bot failed with exit code: \`$CLAUDE_EXIT_CODE\`

**Last output:**
\`\`\`
${LAST_OUTPUT:-No output available}
\`\`\`

**Common causes:**
- Command syntax error in task
- Missing dependencies or tools
- File permission issues
- Out of memory
- Network connectivity issues"
  fi

  # =========================================================================
  # POST ERROR REPORT TO GITHUB
  # =========================================================================
  gh api -X PATCH repos/$GITHUB_REPOSITORY/issues/comments/$PROGRESS_COMMENT_ID \
    -f body="$ERROR_DETAILS

---

**Debug Information:**
- **Exit Code:** \`$CLAUDE_EXIT_CODE\`
- **Timeout:** ${TIMEOUT_VALUE}s (${TIMEOUT_MINUTES:-N/A} minutes)
- **Branch:** \`$BRANCH_NAME\`
- **Workflow Run:** [View logs](https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)

<details>
<summary>📋 Full output (last 200 lines - click to expand)</summary>

\`\`\`
$(tail -n 200 "$PROGRESS_OUTPUT_FILE" 2>/dev/null || tail -n 200 "$JSON_OUTPUT_FILE" 2>/dev/null || echo "No output available")
\`\`\`

</details>"

  exit $CLAUDE_EXIT_CODE
fi

echo "🎉 Claude Bot finished!"
