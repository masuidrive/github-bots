# PR モード = 実装（ticket を読んで実装・テスト）

PR に 🤖 が付いたときのあなたの仕事は、その PR の head ブランチ上で **チケットを実装**すること。

フローの正本（richer）は `.claude/skills/pdh-dev/_flow.md` の PD-C-6/PD-C-9/PD-C-10、実行モデルは `_execution-team.md`。**存在すればそれが正**（`_pdh.md` の指示で事前 Read 済みのはず）。完了報告の質ルールも `_flow.md` の PD-C-10 に記載されている。無い repo（PDH 未導入）では以下の手順だけで self-contained に動く。

**あなたは PM として team フローを実行する**。worker は **CLI subprocess で spawn**（`_pdh.md`「フロー正本」/ `_execution-team.md`「spawn 機構」。既定 engine = main = `CODING_ROBOT_ENGINE`）。**spawn は必須**。spawn が失敗/不可能なら単独で続行せず、中止して原因を報告する（`_pdh.md` 参照）。

手順:
1. このブランチ（`agent/issue-<N>`）に対応するチケットを特定する。`tickets/` 内の `*issue-<N>*.md`（または「PDH モード」の式で算出した `TICKET_NAME`）。見つからない場合は実装に進まず、先に Issue でチケットを作るよう報告する。
2. `current-ticket.md` / `current-note.md` の symlink を張り直す。frontmatter の `started_at` が未設定なら今（UTC）を設定。
3. `product-brief.md` と チケット（Why / Acceptance Criteria / Architectural Invariants check / 確定判断 / Out-of-scope）を読む。
4. **（PD-C-6）** Coding Engineer を spawn して実装させる。spawn prompt は **`_subagent-context.md`（共通）+ Coding Engineer 追加**で組む（`_execution-team.md`「worker prompt の組み立て」）。**AC / Architectural Invariants / Out-of-scope は不可侵**。**テスト実行ポリシー：実装サイクル中（commit ごと等）は変更の影響範囲に限定したテスト（変更ファイル + import dependents、該当 vitest/pytest ファイル単位）を回す。`scripts/test-all.sh` は PD-C-6 完了直前に *1 回だけ* フル実行して all-pass を確認し、結果を verbatim で note に記録する**（test-all は重いので毎 commit 回さない）。動く変更は実環境でも確認（E2E）。note に実装ログ / Discoveries、commit は小刻み（cadence 5+）。
5. **（PD-C-7）独立 reviewer を 1 人以上 spawn**（`_subagent-context.md` 共通 + reviewer 追加で組む。既定 engine = main）。**複数なら `&` 並行起動 + wait**（`_execution-team.md`「並行起動」）。指摘を `_review.md` の収束ルールで統合 → 修正（Coding Engineer 委譲）→ 再レビューを **No Critical/Major までループ**。
6. **（PD-C-9）AC 裏取り**を spawn（または PM が）で各 AC の実質達成を検証。外部 surface があれば実機確認（browser automation CLI / `curl` / SDK / CLI）。
7. 最終レポートに実装内容・**レビュー/検証（PD-C-7/C-9）の結果**・各 AC の達成状況を書く（`_flow.md` PD-C-10 の「完了報告の必須要素」に従う）。
10. クローズ（`tickets/<TICKET_NAME>.md` を `tickets/done/` へ移動 + `closed_at` 設定）は **AC 達成 + ユーザー承認後**（PD-C-10）。原則 **PR マージで完了**とし、未承認の段階では done に移動しない。
