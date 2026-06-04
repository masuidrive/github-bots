# PDH モード（このリポジトリは Product Delivery Hierarchy 構成）

このリポジトリには `product-brief.md` と `tickets/` があり、**PDH（ticket 駆動）** で運用する。すべての作業は ticket を単位に行い、`product-brief.md` が全判断の基準。

## チケットの単位・ブランチ・命名（決定的）
- 1 Issue = 1 ticket = 1 作業単位。ブランチは `agent/issue-<N>`。
- チケット名は **決定的**に算出する（再実行しても必ず同じ名前 → 重複作成を防ぐ）:
  ```bash
  CREATED_AT=$(gh issue view "$ISSUE_NUMBER" --repo "$GITHUB_REPOSITORY" --json createdAt -q .createdAt)
  TS=$(date -u -d "$CREATED_AT" +%y%m%d-%H%M%S)   # 例: 260528-145617
  TICKET_NAME="${TS}-issue-${ISSUE_NUMBER}"        # 例: 260528-145617-issue-7
  ```

## 永続 / 揮発
| ファイル | 役割 | 扱い |
|---|---|---|
| `tickets/<TICKET_NAME>.md` | チケット本体（オープン） | commit（永続・正） |
| `tickets/<TICKET_NAME>-note.md` | 作業ノート | commit（永続） |
| `tickets/done/<TICKET_NAME>.md` | クローズ済み | commit（永続） |
| `current-ticket.md` / `current-note.md` | 作業ビュー（symlink） | `.gitignore` 済・毎回張り直す（揮発） |

実行の最初に symlink を張り直す（ticket.sh と同じ流儀。これにより current-*.md を参照する指示がそのまま機能する）:
```bash
ln -sf "tickets/${TICKET_NAME}.md"      current-ticket.md
ln -sf "tickets/${TICKET_NAME}-note.md" current-note.md
```

## チケット / ノートは `ticket.sh new` で作る
ファイル本体は `ticket.sh new` で生成する（テンプレ・frontmatter・ノートを正しく作るため）。`start` / `close` は使わない（ブランチは `agent/issue-N`、`current-*.md` は下記のとおり自分で symlink する）。

```bash
bash ticket.sh new "issue-${ISSUE_NUMBER}" --created-at "$TS"
```
これで以下が生成される:
- `tickets/${TICKET_NAME}.md`（本体。`.ticket-config.yaml` の `default_content` ベース）
- `tickets/${TICKET_NAME}-note.md`（ノート。`note_content` ベース）
- frontmatter の `created_at`（= Issue createdAt UTC）も ticket.sh が付与。

**find-or-create（重複させない）**: チケット名は決定的なので、`new` の前に `tickets/${TICKET_NAME}.md` と `tickets/done/${TICKET_NAME}.md` の有無を確認し、**無い時だけ `new`** する。既にあればそれを使う。

生成後、本体の各セクション（Why / What+Acceptance Criteria / Architectural Invariants check / 確定判断 / Out-of-scope）を Issue・`product-brief.md` から埋める。

`started_at`（実装開始時 UTC）/ `closed_at`（クローズ時 UTC）は `start`/`close` を使わないので、必要なタイミングで frontmatter を直接更新する。

## フロー正本（共有 core）

PDH フローの正本は `.claude/skills/pdh-dev/` の共有 core にある。以下のファイルが存在すれば **この順で Read** してフローに従うこと:

1. `.claude/skills/pdh-dev/_principles.md` — 最重要原則・核となる設計選択
2. `.claude/skills/pdh-dev/_reference.md` — 用語・ステップ遷移・ticket/note構造・AC規則・責務境界
3. `.claude/skills/pdh-dev/_flow.md` — PD-C-1/6/7/9/10 の手順本体
4. `.claude/skills/pdh-dev/_review.md` — レビューパターン・観点・収束診断・裏取りルール
5. `.claude/skills/pdh-dev/_collaboration.md` — ユーザ相談ルール・中止フロー
6. `.claude/skills/pdh-dev/_execution-team.md` — **実行モデル: team**（あなたは PM として worker を spawn する。spawn 機構・並行起動パターンを含む）
7. `.claude/skills/pdh-dev/_subagent-context.md` — **worker 共通プロンプト**（spawn する全 worker の prompt 冒頭に渡す土台。PDH 前提・読むべき原則ファイル・チケット位置・不可侵・出力先）

**あなた（bot の main agent）は PM として team フローを実行する。** worker（Coding Engineer / reviewer / AC 裏取り 等）は **CLI subprocess で spawn** する（`_execution-team.md`「spawn 機構」）:
- **main engine** = `CODING_ROBOT_ENGINE`（この run の engine。Bash から見える）。
- **worker は既定で main と同じ engine**。起動コマンド（claude / codex 両方、**bypass 権限**で）と並行起動・結果回収の作法は `_execution-team.md`「spawn 機構」に self-contained に記載されている**それをそのまま使う**。per-role の上書きはプロジェクト規約に指定があるときのみ（混在可）。
- 各 worker は **専用の result ファイル**に書かせ、あなたが読んで統合する。並行起動は background。
- 認証は run の環境変数を subprocess が継承する（追加設定不要）。
- **spawn は必須**。worker の spawn が失敗/不可能な場合（CLI 不在・auth 不在・exit 非ゼロ等）は、**単独で続行しない**。worker 起動後は必ず `wait` 後に `rc=$?` を保存し、`/tmp/agent-result.md` の final report に「何の spawn が・どう失敗したか（コマンド・rc、result/stderr の `ls -l`、`tail -120 stderr.log`）」を書いてエラー報告する（独立レビュー無しで PR を出さない）。result が空/無いことだけで silent failure と誤判定せず、rc と stderr tail をセットで確認・報告する。

ガード（存在チェック）: 上記ファイルが **揃っていれば Read してその正本に従う**（richer なフロー定義）。**core が無い / 一部欠けている repo（PDH 未導入の repo 等）では、Read を試みて無いものはスキップし、`_issue.md` / `_pr.md` に self-contained に書かれた手順だけで動く**（従来どおり動作する）。core の有無で bot の動作が壊れないこと。

## 不可侵 / 承認
- Acceptance Criteria・Architectural Invariants・Out-of-scope は **ユーザー承認なしに変更しない**。
- `product-brief.md` を編集する場合は内容を提示して承認を得る。
