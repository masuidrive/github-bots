# Issue モード = ticket 作成 →（承認後）実装して PR 作成

Issue に 🤖 が付いたら、**トリガーコメントの内容で 2 フェーズを判別**する。デフォルトは **B（実装）**。明確に「質問」「修正・追加指示」「一時停止」のシグナルがある場合だけ **A（ticket 作成/更新フェーズ）**に回す。

### 判定手順

1. `:robot:` / 🤖（および前後の空白）を除いた残り文字列を `RESIDUAL` とする。`RESIDUAL` を normalize：trim、lowercase、全角→半角、末尾の `!` `！` `.` `。` を削除。

2. 次の順で判定：

   a. **`RESIDUAL` が空**（🤖 だけの空打ち）→ **A**。チケットがあれば書き換えず、現状の AC を再掲して「実装に進むには承認語、修正したい点があれば指示でコメント」と案内するだけ。

   b. **質問シグナルを含む** → **A（質問への回答フェーズ）**。コードは書かず、コメントで回答し、必要なら AC を再掲する。
      - 末尾に `?` または `？`
      - `ですか` / `ますか` / `でしょうか` / `教えて` / `何` / `どう` / `なぜ` / `どうして` / `いつ` / `どこ` / `理由` を含む
      - 英: `?` / `why` / `what` / `how` / `when` / `where` / `can you explain` / `is this` を含む

   c. **修正・追加指示シグナルを含む** → **A（チケット更新フェーズ）**。AC や Out-of-scope や Why を差分更新して、再度承認を促す。
      - `直して` / `修正` / `変更` / `追加` / `削除` / `書き換え` / `書いて` / `入れて` / `外して` / `含めて` / `除いて` / `差し替え` / `差し戻し` / `加えて` / `減らして` / `消して`
      - `ac\d` / `acceptance` / `out-of-scope` / `スコープ` / `不可侵` / `architectural invariants` / `why`（本文への言及として）
      - 英: `fix` / `change` / `update` / `add` / `remove` / `replace` / `include` / `exclude` / `instead`
      - 具体的なファイルパス（`/` または `.` を挟む英数字列）が含まれる

   d. **一時停止シグナルを含む** → **A**。実装には進まず、現状報告のみ。
      - `待って` / `保留` / `やめて` / `キャンセル` / `一旦` / `止めて` / `NG` / `no` / `cancel` / `wait` / `hold` / `pause` / `stop`

   e. **上記いずれにも当てはまらない** → **B（実装フェーズ）**。「whitelist 一致」を求めない。短い肯定・任せる系の言い回し（`ok` / `yes` / `lgtm` / `go` / `start` / `承認` / `実装` / `進めて` / `よろしく` / `お願い` / `任せた` / `もちろん` / `ぜひ` / 👍 / ❤️ / 🎉 / 🚀 / ✅ など）はすべてここに落ちる。

### 例

| コメント | 判定 | 理由 |
|---|---|---|
| `🤖 ok` / `🤖 yes` / `🤖 よろしく` / `🤖 お願いします` / `🤖 任せた` / `👍🤖` | B | (e) デフォルト |
| `🤖` のみ | A | (a) 空 |
| `🤖 これでいい？` / `🤖 AC2 って何を指してる？` | A | (b) 質問 |
| `🤖 AC2 を直して` / `🤖 README にも書いて` / `🤖 instead use Flask` | A | (c) 修正指示 |
| `🤖 待って、もう少し考える` / `🤖 cancel` | A | (d) 停止 |

**設計意図**：AC 承認 gate を破る誤実装より、誤って A（差し戻し）に落ちる方がコストが小さい — のはずだったが、運用上「短文の肯定」を毎回 whitelist 拡張で追うのは無理ゲーだった。代わりに「修正・質問・停止のシグナルを能動的に検出し、それ以外は承認」へ反転する。誤承認のリスクは「修正指示シグナルの語彙」を厚めに持つことで吸収する（足りなければ追加する）。

---

## A. ticket 作成フェーズ（PD-C-1 相当）

フローの正本（richer）は `.claude/skills/pdh-dev/_flow.md` の PD-C-1。**存在すればそれが正**（`_pdh.md` の指示で事前 Read 済みのはず）。無い repo（PDH 未導入）では以下の手順だけで self-contained に動く。

1. `TICKET_NAME` を算出（「PDH モード」）。find-or-create: 無ければ `bash ticket.sh new "issue-${ISSUE_NUMBER}" --created-at "$TS"` で本体＋ノート生成。`current-ticket.md` / `current-note.md` を symlink。
   - **既にチケットがあり、Issue 本文・コメントに前回から新情報が無い場合**（例: `🤖` だけの空打ち）は、**チケットを書き直さない**。現状の Acceptance Criteria を再掲し、「実装に進むには承認トークン（例 `🤖 ok`）でコメント」と再案内するだけにする。差分（新しい指示・情報）があるときだけ更新する。
2. Issue 本文・コメント・`product-brief.md` から **Why / What+Acceptance Criteria / Architectural Invariants check / 確定判断 / Out-of-scope** を埋める。
   - 曖昧・AC 未確定は勝手に決めない。`product-brief.md` と矛盾する要求は実装に進まず Product Brief 更新の要否を提起する。
   - **調査は推奨**: 実現可能性確認のため使い捨てコードを動かす / サーバ起動 + `agent-browser`・`curl` で挙動観察してよい（成果物コードは commit しない）。
3. ticket と note を `agent/issue-${ISSUE_NUMBER}` ブランチに commit / push する。**PR は作らない。プロダクトコードは書かない。**
4. 最終コメントに「チケット要約 + 提案 Acceptance Criteria（**承認待ち**）」を書く。**承認して実装に進むには、この Issue に承認キーワード（例: `承認 🤖`）でコメントするよう案内**する（AC を直したい場合はその旨も案内）。
   - **承認者はチケットファイルを開かない前提**で、コメントだけで AC の妥当性を判断できるようにする。AC に加えて **Why（1 行）** と **Out-of-scope** を必ず併記する（必要なら主要な確定判断も 1〜2 行）。AC は番号だけでなく内容を書く。
   - **チケット本体とノートへのリンクだけ**を載せる（冗長な「Changes Made」一覧や各ファイルの説明は不要 — 中身の要約は上の Why / AC / Out-of-scope で既に伝わっている）。リンクは **markdown 形式 `[<path>](url)`**（表示テキスト = パス）で、`[tickets/<TICKET_NAME>.md](https://github.com/${GITHUB_REPOSITORY}/blob/agent/issue-${ISSUE_NUMBER}/tickets/<TICKET_NAME>.md)` のように書く。
   - **内部メカニクスを並べない**: commit hash・「push 済み」等は書かない。チケットの所在は「`agent/issue-${ISSUE_NUMBER}` に作成（コードは未変更）」の 1 行で足りる。
   - **PR メタデータマーカー（`{{{{{pull-request-*}}}}}`）は出さない**。この段階では Create-PR リンクを出さない（コードがまだ無いため）。

---

## B. 実装フェーズ（PD-C-6 → PD-C-10）

フローの正本（richer）は `.claude/skills/pdh-dev/_flow.md` の PD-C-6/PD-C-9/PD-C-10、実行モデルは `_execution-team.md`。**存在すればそれが正**（`_pdh.md` の指示で事前 Read 済みのはず）。完了報告の質ルールも `_flow.md` の PD-C-10 に記載されている。無い repo（PDH 未導入）では以下の手順だけで self-contained に動く。

**あなたは PM として team フローを実行する**。worker は **CLI subprocess で spawn**（`_pdh.md`「フロー正本」/ `_execution-team.md`「spawn 機構」。既定 engine = main = `CODING_ROBOT_ENGINE`）。**spawn は必須**。spawn が失敗/不可能なら単独で続行せず、中止して原因を報告する（`_pdh.md` 参照）。

1. `TICKET_NAME` でチケットを特定する（無ければ実装に進まず、先に A を促す）。`current-ticket.md` / `current-note.md` を symlink。frontmatter `started_at` を今（UTC）に設定。
2. `product-brief.md` と ticket（Why / AC / Architectural Invariants check / 確定判断 / Out-of-scope）を読む。**AC / Architectural Invariants / Out-of-scope は不可侵**。逸脱が要るなら止めてユーザーに諮る。
3. **（PD-C-6）** Coding Engineer を spawn して実装させる。spawn prompt は **`_subagent-context.md`（共通）+ Coding Engineer 追加**で組む（`_execution-team.md`「worker prompt の組み立て」）。**テスト実行ポリシー：実装サイクル中（commit ごと等）は変更の影響範囲に限定したテスト（変更ファイル + import dependents、該当 vitest/pytest ファイル単位）を回す。`scripts/test-all.sh` は PD-C-6 完了直前に *1 回だけ* フル実行して all-pass を確認し、結果を verbatim で note に記録する**（test-all は重いので毎 commit 回さない）。**test-all 失敗時：** 原因を triage する。(a) 本変更起因 → エンジニアに修正委譲して再実行（再現するなら scoped 不足を疑い変更影響範囲を再判定）。(b) `_review.md`「スコープ外の既存問題の扱い」の自動分類に該当する pre-existing minor → 同一チケット内で修正。(c) 環境ブロッカー / pre-existing major → verbatim 出力とともにユーザーに 3 択（fix / deferred / cancel）で諮り、合意なしに PD-C-7 へ進まない。**同種失敗が 3 round 連続したら `_review.md`「収束性診断」と同じく escalate**（無限 loop 防止）。動く変更は実環境でも確認（E2E）。note に実装ログ / Discoveries、commit は小刻み（cadence 5+）して push。
4. **（PD-C-7）独立 reviewer を 1 人以上 spawn**（`_subagent-context.md` 共通 + reviewer 追加で組む。既定 engine = main）。**複数なら `&` 並行起動 + wait**（`_execution-team.md`「並行起動」）。指摘を `_review.md` の収束ルールで統合 → 修正（Coding Engineer に委譲）→ 再レビューを **No Critical/Major までループ**。
5. **（PD-C-9）AC 裏取り**を spawn（または PM が）で各 AC の実質達成を検証。外部 surface があれば実機確認（browser automation CLI / `curl` / SDK / CLI）。
6. **PR メタデータを出す**（実装後なので内容は実装済みの機能を表す）。`/tmp/agent-result.md` の末尾に PR タイトル/本文をマーカー（`{{{{{pull-request-title}}}}}` / `{{{{{pull-request-body}}}}}`、system.md の PR metadata 節参照）で書く。harness がこれを「Create Pull Request」リンクにし、**ユーザーがリンクを押して PR を作る**（bot は PR を直接作らない）。既に PR がある場合はマーカーを出さなくてよい。
7. 最終コメントに実装内容・**レビュー/検証（PD-C-7/C-9）の結果**・各 AC の達成状況を書く（`_flow.md` PD-C-10 の「完了報告の必須要素」に従う）。

### B で出す PR メタデータのタイトル / 本文
**実装済みの機能**を説明する（チケット作成という作業ではない）。
- **タイトル**: 機能ベース。機能に合った conventional commit type。例 `feat: helloworld に名前引数を追加`（`docs:` にしない）。
- **本文**:
  - **Why**: なぜこの機能が必要か（ticket の Why）。
  - **What**: 実装した内容（= AC を満たす観察可能な振る舞い）。
  - **Verification**: 実行したテストと結果、E2E 確認。
  - **Notes**: 補足（あれば）。
  - 末尾に `Closes #${ISSUE_NUMBER}`。

---

## 共通の禁止
- A フェーズで成果物コードを commit しない（使い捨ての確認コードも commit しない）。
- AC / Architectural Invariants / Out-of-scope をユーザー承認なしに変更しない。
- `product-brief.md` の編集は内容提示＋承認を得る。
