# PDH + 判断ボード + tether を、このプロジェクトへ導入する

**この文書は、読んだ agent がそのまま実行するための手順である。**上から順に実行すること。

3 つを組み合わせると、次のことができるようになる。

| | 何ができるようになるか |
|---|---|
| **PDH** | 作業を ticket として起こし、実装前と close 前に人の承認を挟んで進める |
| **判断ボード**（decision.hanger） | その承認を、**人がブラウザで選んで送信する**形で受け取る。回答は board に残る |
| **tether** | 回答が入ったら、**board を発行した tmux pane へ 1 行打ち込んで** agent に知らせる |

**それぞれ別に更新されるので、この文書は «順番と、つなぎ目» だけを書く。**
各プロジェクトの入れ方は、そのプロジェクトの手順書を読むこと。

---

## ⚠ 順番が 1 つだけ効く

**PDH を先に入れる。**判断ボードの手順は「`CLAUDE.md` に発行先の節を追記する」を含むので、
**PDH が `CLAUDE.md` を作ったあとでないと追記先が無い。**

tether はいつでもよい（無くても判断ボードは動く。回答は `watch` で受け取れる）。

---

## 手順 1 — PDH を入れる

プロジェクトのルートで、次を読んで実行する。

```
https://github.com/masuidrive/pdh の INSTALL.md を読んで、このプロジェクトに PDH を導入して。
```

🔗 https://github.com/masuidrive/pdh/blob/main/INSTALL.md

`ticket.sh` の導入・skill の配置・`.claude/settings.json`・`CLAUDE.md` の雛形・
`scripts/test-all.sh` などが作られる。⚠ **Codex CLI も使うなら、`.agents/skills/` への
symlink まで作らせること**（INSTALL.md に節がある）。

## 手順 2 — 判断ボードの発行先を入れる

```
https://decision.hanger.fctry.jp/agent/install.md を読んで、そのとおりに導入して。
```

🔗 https://decision.hanger.fctry.jp/agent/install.md （**認証なしで読める**）

client の取得・`CLAUDE.md` への追記・1 枚出して通るところまで、agent が実行する。
⚠ **人がやるのは、途中の `./decision-board.sh login` をブラウザで承認する 1 回だけ。**
token は `~/.hangar/token` に 30 日保存され、**マシン共通**なので、
同じマシンの 2 つ目のプロジェクトではこの承認は要らない。

### ⚠ install.md が書かせるのは «発行先» だけである

`install.md` が `CLAUDE.md` に足すのは «どこへ発行するか» であり、**«いつ board を出すか» は書かれない。**
発行先だけ入れると、agent は判断を求めるときに会話へ材料を並べて `AskUserQuestion` を出す形へ戻る。
skill は入っているのに呼ばれない、という状態になる。

**次の節も `CLAUDE.md` へ足すこと**（PDH 運用について書いてある節の近くがよい）。

~~~markdown
## ticket / close の判断は判断ボードを先に出す

**ticket に関する判断と close の判断をユーザへ求めるときは、判断ボードを作り、それを先に提示する。**
会話に材料を書き並べて `AskUserQuestion` を出す形は取らない。

判断ボードとは、ユーザに留保された判断について coding agent が作成する Completed Staff Work である。
完成の条件は 1 つ — ユーザが追加の調査をせずに、求められた判断を下せること。

gate ごとに使う skill が違う。

- PDH-ticket-human-review（AC 承認・実装に入る前）→ `/pdh-ticket-decision-board`
- PDH-human-review（close 前）→ `/pdh-close-decision-board`。データ構造の変更と、外部から見える契約の変更を重点的に書く

両 gate の共通規則と renderer は `pdh-decision-board-base` にあり、上の 2 skill はどちらもそれを読む。
board の文章は `common-writing` に従う。**board の中身の作り方・必須ルール・組み方は skill が正なので、ここに写さない。**

ほかに board を作る判断。

- ticket の scope に関する判断（finding を本 ticket で直すか / 起票するか / 記録のみか）
- 次にどの ticket を流すかの割り当て

判断が 1 件でも・選択肢が単純でも board を作る。後から «何を根拠に決めたか» を引く必要があるため、例外を作らない。
~~~

## 手順 3 — tether を入れる（任意・マシンに 1 回だけ）

**プロジェクト側の作業は無い。**`decision-board.sh` が発行のとき `tether link` を自分で拾い、
`tether watching` で「`watch` が要るか」を判断する。⚠ **設定ファイルへ書くことは何も無い。**

マシンに入っていなければ、次を 1 回だけ実行する。

```bash
tether install       # ログイン時に自動起動させる（systemd / launchd）
tether agent-setup   # agent の hook を設定する（pane の状態を tether へ知らせる）
tether connect       # 複数マシンを 1 つの hub にまとめる場合だけ
```

⚠ **binary の入手方法は、この文書には書かない。**運用しているhub から
`tether update` で取る形になっているため、**hub の場所を知っている人に聞くこと。**
入っているかどうかは `command -v tether || command -v guppi` で分かる
（改名の途中なので、**どちらの名前も実在しうる**）。

---

## 確かめる

**board を 1 枚出して、最後の行を見る。**

```bash
./decision-board.sh publish --title '導入の確認' --html <board.html> --gate close
```

```
board: https://decision.hanger.fctry.jp/b/xxxxxxxxxxxxxxxx
  tether が回答を見張ります。watch は要りません。回答が入ったら知らせが来ます。
```

⚠ **この最後の 1 行が «判断» である。**agent が覚える規則はこれ 1 つでよい —
**publish が書いたとおりにする。**

- 「**watch は要りません**」→ そのまま手番を終えてよい。回答が入ると pane に知らせが来る
- 「**見張るものがありません**」→ `./decision-board.sh watch <board id>` を背後で走らせる
  （tether が無い・起動していない・古い版のとき。**聞けないときは必ずこちら側へ倒れる**）

確かめ終わったら、**その board は終了にする**（`./decision-board.sh close <board id>`）。
⚠ **答えを反映した board を閉じないと、一覧に «未回答» として残り続ける。**

---

## それぞれの更新の仕方

**3 つは別々に更新される。まとめて更新する手段は無い。**

| | 更新の仕方 |
|---|---|
| PDH | `pdh-update`（skill）。上流の INSTALL.md「既存プロジェクトのアップデート」に従う |
| 判断ボードの client | `./decision-board.sh selfupdate`（配布元の app から取り直す。**GitHub からは取らない**） |
| tether | `tether update`（hub から binary を取り直して再起動する） |
