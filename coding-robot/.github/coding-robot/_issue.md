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

フロー正本は `.claude/skills/pdh-dev/_flow.md` の PD-C-1（`_pdh.md` の指示で事前 Read 済み）。**正本に従う**。以下は coding-robot harness 固有の補足のみ：

1. `TICKET_NAME` を算出（「PDH モード」）。find-or-create: 無ければ `bash ticket.sh new "issue-${ISSUE_NUMBER}" --created-at "$TS"` で本体＋ノート生成。`current-ticket.md` / `current-note.md` を symlink。
   - **既にチケットがあり、Issue 本文・コメントに前回から新情報が無い場合**（例: `🤖` だけの空打ち）は、**チケットを書き直さない**。現状の Acceptance Criteria を再掲し、「実装に進むには承認トークン（例 `🤖 ok`）でコメント」と再案内するだけにする。差分（新しい指示・情報）があるときだけ更新する。
2. ticket と note の埋め方・AC の扱いは `_flow.md` PD-C-1 に従う（AC は ticket.md のみ、note にはコピーしない／曖昧 AC は勝手に決めない／`product-brief.md` 矛盾は実装に進まず提起、など）。実現可能性の調査として使い捨てコード / サーバ起動 + `agent-browser` / `curl` を使ってよい（成果物コードは commit しない）。
3. ticket と note を `agent/issue-${ISSUE_NUMBER}` ブランチに commit / push する。**PR は作らない。プロダクトコードは書かない。**
4. 最終コメントに「チケット要約 + 提案 Acceptance Criteria（**承認待ち**）」を書く。**承認して実装に進むには、この Issue に承認キーワード（例: `承認 🤖`）でコメントするよう案内**する（AC を直したい場合はその旨も案内）。
   - **承認者はチケットファイルを開かない前提**で、コメントだけで AC の妥当性を判断できるようにする。AC に加えて **Why（1 行）** と **Out-of-scope** を必ず併記する（必要なら主要な確定判断も 1〜2 行）。AC は番号だけでなく内容を書く。
   - **チケット本体とノートへのリンクだけ**を載せる（冗長な「Changes Made」一覧や各ファイルの説明は不要 — 中身の要約は上の Why / AC / Out-of-scope で既に伝わっている）。リンクは **markdown 形式 `[<path>](url)`**（表示テキスト = パス）で、`[tickets/<TICKET_NAME>.md](https://github.com/${GITHUB_REPOSITORY}/blob/agent/issue-${ISSUE_NUMBER}/tickets/<TICKET_NAME>.md)` のように書く。
   - **内部メカニクスを並べない**: commit hash・「push 済み」等は書かない。チケットの所在は「`agent/issue-${ISSUE_NUMBER}` に作成（コードは未変更）」の 1 行で足りる。
   - **PR メタデータマーカー（`{{{{{pull-request-*}}}}}`）は出さない**。この段階では Create-PR リンクを出さない（コードがまだ無いため）。

---

## B. 実装フェーズ（PD-C-6 → PD-C-10）

フロー正本は `.claude/skills/pdh-dev/_flow.md`（PD-C-6/7/9/10）/ `_review.md`（収束性診断・スコープ外既存問題の扱い・裏取りルール）/ `_execution-team.md`（spawn 機構・並行起動・worker prompt の組み立て）/ `_subagent-context.md`（worker 共通プロンプト）。**正本に従う**。以下は coding-robot harness 固有の補足のみ：

1. `TICKET_NAME` でチケットを特定する（無ければ実装に進まず、先に A を促す）。`current-ticket.md` / `current-note.md` を symlink。frontmatter `started_at` を今（UTC）に設定。
2. **harness の hard timeout 対策（PD-C-6 中）**:
   - **Commit 早期義務**: worker は spawn 後の最初の意味ある変更で *先に commit + push してから* scoped テストを回す（最初の commit は spawn から *15 分以内*が目安）。push されていない作業は harness の hard timeout（`DEADLINE_UNIX`）で消失する。
   - **長時間 gate の前に push**: `scripts/test-all.sh` 等の長時間ジョブを回す前に、未 push の変更があれば必ず push してから実行する。
   - **test-all 前の deadline チェック**: Environment Variables の `DEADLINE_UNIX` を見て、残時間が test-all の想定実行時間 + 5 分のマージンを下回るなら、フル実行せず scoped に留めて「deadline 不足のため test-all はスキップ／scoped で代替、PD-C-9 に委譲」を note に記録して進める（kill されるより合理的）。
   - test cadence 本体（scoped中／test-all 1回／失敗時 triage）と round escalation policy は `_flow.md` PD-C-7 / `_review.md` 収束性診断・スコープ外既存問題の扱い に従う。
3. **worker spawn の失敗報告**: worker 起動後は必ず `wait` 後に `rc=$?` を保存し、`/tmp/agent-result.md` の final report には各 worker の rc、result/stderr の `ls -l`、`tail -120 stderr.log` を含める。result が空/無い場合も、それだけで silent failure と扱わず rc と stderr tail をセットで報告する。spawn が失敗/不可能なら単独で続行せず中止し原因を報告する。
4. **PR メタデータを出す**（実装後なので内容は実装済みの機能を表す）。`/tmp/agent-result.md` の末尾に PR タイトル/本文をマーカー（`{{{{{pull-request-title}}}}}` / `{{{{{pull-request-body}}}}}`、共通 `system.md` の PR metadata 節参照）で書く。harness がこれを「Create Pull Request」リンクにし、**ユーザーがリンクを押して PR を作る**（bot は PR を直接作らない）。既に PR がある場合はマーカーを出さなくてよい。
5. 最終コメントは `_flow.md` PD-C-10 の「完了報告の必須要素」に従う（実装内容・PD-C-7/C-9 結果・各 AC の達成状況）。

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
