# Coding Robot: devcontainer 事前ビルド（prebuild）セットアップ

このドキュメントは、`setup-devcontainer.md` で構築した **compose-based の devcontainer** を前提に、
Coding Robot が 🤖 で起動するたびに devcontainer イメージを丸ごと再ビルドしている問題を解消する
**任意の追加セットアップ手順** です。

> `setup-devcontainer.md` は devcontainer 自体（Dockerfile / devcontainer.json / docker-compose.yml）の構成専用です。
> 本ドキュメントはそれとは独立した「prebuild 機能の導入手順」であり、prebuild が不要なら適用しなくて構いません。

---

## 1. なぜ必要か（背景）

`coding-robot.yml` の `Run Agent in devcontainer` ステップは `devcontainers/ci` に
`imageName` / `cacheFrom` / `push: always` を指定しているが、**compose-based の devcontainer ではこのキャッシュが効かない**。

理由（`devcontainers/ci` の実装）:
- `imageName` / `cacheFrom` を使う registry cache build（`buildImageBase`）は **Dockerfile-based の devcontainer 専用**。
- `devcontainer.json` が `dockerComposeFile` を指す compose-based の場合、`config.getDockerfile()` が null を返して
  `buildImageBase` に到達せず、`devcontainer build` / `up` が `COMPOSE_DOCKER_CLI_BUILD=1`（classic builder）で
  compose build を実行する。classic builder の `--cache-from` は registry の inline cache を確実にはヒットさせない。

結果として **🤖 起動のたびにイメージを全ステージ再ビルド**（pyenv の Python ソースコンパイル・Playwright chromium bake・apt 等）し、
1 run あたりの大半（実測で ~14 分 / 1 run の 8 割超）がビルドに費やされ、GitHub Actions の分を無駄に消費する。

## 2. 仕組み（このセットアップで何が変わるか）

1. **専用の prebuild ワークフロー**（`devcontainer-prebuild.yml`）が `.devcontainer/**` などイメージに影響する変更の push 時にだけ
   イメージをビルドして GHCR の `:latest` に publish する（＝ビルドは「devcontainer をいじった時だけ・月数回」）。
2. **`coding-robot.yml` は事前ビルド済みイメージを `docker pull` するだけ**にする。pull したイメージを
   `DEVCONTAINER_IMAGE` で compose に渡すと、`docker compose build` が全層キャッシュヒットになり、
   apt / pyenv / chromium bake が再実行されない。毎 run の `push: always`（GHCR への push）も廃止する。

これにより 🤖 1 run の所要は「~14 分のフルビルド」から「数分の pull のみ」に短縮され、
run 時間は agent の実作業時間が支配的になる。

## 3. 前提条件

- devcontainer が **compose-based**（`devcontainer.json` に `dockerComposeFile` 指定）であること。
  Dockerfile-based の devcontainer では `devcontainers/ci` の `imageName`/`cacheFrom` が元々効くため本手順は不要。
- GitHub Packages（GHCR）が利用可能で、ワークフローに `packages: write` 権限があること（既存の coding-robot.yml で付与済み）。

---

## 4. セットアップ手順

### 4.1. `.github/workflows/devcontainer-prebuild.yml` を新規作成

以下をそのまま追加する。`${{ github.repository }}` を使うのでリポジトリ名のハードコードは不要。

> **⚠ `paths` は「Dockerfile が build context から `COPY` / `ADD` する全ファイル」を必ず網羅すること。**
> これらはイメージレイヤの cache key になる。漏らすと、そのファイルだけ変更された時に prebuild が再 publish されず、
> 以降の coding-robot run が該当レイヤだけ cache miss して**毎 run 再ビルド**になる。
> 例: Dockerfile が Playwright の pin を読むために `COPY frontend/package.json` していれば、`frontend/package.json` も `paths` に含める。

```yaml
name: Devcontainer Prebuild

# Coding Robot の devcontainer イメージを事前ビルドして GHCR に publish する。
# coding-robot.yml はこのイメージを pull するだけにし、毎 run のフルビルドを無くす。
# TRIGGER: イメージ内容に影響する変更（.devcontainer/** と、Dockerfile が COPY する cache-key ファイル）の push のみ。
on:
  push:
    branches: [main]
    paths:
      - ".devcontainer/**"
      # ▼ Dockerfile が build context から COPY/ADD するファイルを列挙（イメージの cache key）。
      #   プロジェクトに合わせて追加・削除すること。例:
      # - "frontend/package.json"
      # - "scripts/bake-playwright-chromium.sh"
      - ".github/workflows/devcontainer-prebuild.yml"
  # 手動再ビルド（upstream 固定ツールのリフレッシュ等）+ ブランチからの検証用。
  workflow_dispatch:
  # floating な upstream install（CLI バイナリ等）が古くなりすぎないよう週次リフレッシュ。
  schedule:
    - cron: "17 4 * * 1" # Mondays 04:17 UTC

# 同じ :latest tag への push が競合しないように。
concurrency:
  group: devcontainer-prebuild-${{ github.ref }}
  cancel-in-progress: true

jobs:
  prebuild:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Login to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # イメージをビルドして GHCR に publish。coding-robot.yml がこの :latest を pull して全層再利用する。
      # NOTE: GHCR の image ref は小文字必須。${{ github.repository }} に大文字を含む場合は別途小文字化が必要
      #       （多くの org/repo slug は小文字なので通常は不要）。
      - name: Build and push devcontainer image
        uses: devcontainers/ci@v0.3
        with:
          configFile: .devcontainer/devcontainer.json
          imageName: ghcr.io/${{ github.repository }}/devcontainer-ci
          imageTag: latest
          push: always
          cacheFrom: |
            ghcr.io/${{ github.repository }}/devcontainer-ci:latest
          # 焼いたイメージが壊れていたら次の 🤖 run ではなくここで落とす smoke test。
          runCmd: |
            set -e
            echo "Verifying baked toolchain..."
            # プロジェクトに合わせて確認コマンドを調整する
            command -v git
            echo "devcontainer image built ok"
```

### 4.2. `.devcontainer/docker-compose.yml` の app サービスに `image:` と `cache_from:` を追加

pull 済みの prebuilt イメージを compose の build キャッシュとして使わせる。
CI では `DEVCONTAINER_IMAGE` に GHCR の prebuilt が入り、ローカルでは未設定なので安定したローカル tag に
フォールバックする（VS Code 等のローカル利用は挙動不変）。

```yaml
services:
  app:
    # CI(coding-robot) では DEVCONTAINER_IMAGE が prebuilt GHCR イメージを指す。run が事前 pull するので
    # この `docker compose build` は全層キャッシュヒットになり、どのステージも再実行されない。
    # ローカルでは未設定 → 安定したローカル tag にフォールバック（VS Code の挙動は不変）。
    image: ${DEVCONTAINER_IMAGE:-coding-robot-devcontainer:local}
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile
      # prebuilt イメージのレイヤを build キャッシュとして再利用。ローカルでは ref が miss するだけで無害。
      cache_from:
        - ${DEVCONTAINER_IMAGE:-coding-robot-devcontainer:local}
    # ... 既存の volumes / environment / working_dir / command はそのまま ...
```

### 4.3. `coding-robot.yml` を patch

#### (a) 事前ビルド済みイメージを pull するステップを「Run Agent in devcontainer」の直前に追加

```yaml
      # 事前ビルド済み devcontainer イメージを pull する。Devcontainer Prebuild ワークフローが
      # GHCR へ publish 済み。DEVCONTAINER_IMAGE に渡すと下の compose build が全層キャッシュヒットになり、
      # apt / pyenv コンパイル / chromium bake 等が再実行されない。
      # 万一 prebuilt が無い場合(初回など)はフルビルドにフォールバックするよう pull 失敗は無視する。
      - name: Pull prebuilt devcontainer image
        id: prebuilt
        run: |
          IMAGE="ghcr.io/${{ github.repository }}/devcontainer-ci:latest"
          IMAGE="$(printf '%s' "$IMAGE" | tr '[:upper:]' '[:lower:]')"  # GHCR ref は小文字必須
          echo "Pulling prebuilt image: $IMAGE"
          if docker pull "$IMAGE"; then
            echo "image=$IMAGE" >> "$GITHUB_OUTPUT"
            echo "✅ Prebuilt image pulled; compose build will reuse its layers."
          else
            echo "⚠️ Prebuilt image not found; devcontainer will build from scratch this run."
            echo "image=" >> "$GITHUB_OUTPUT"
          fi
```

#### (b) 「Run Agent in devcontainer」ステップを次のように変更

- `env:`（**ステップ直下の runner env**。`with.env` ではない）に `DEVCONTAINER_IMAGE` を追加
- `push: always` → `push: never`
- `imageName:` と `cacheFrom:` を**削除**（compose-based では `devcontainers/ci` に無視される dead config）

```yaml
      - name: Run Agent in devcontainer
        id: run_claude
        uses: devcontainers/ci@v0.3
        # DEVCONTAINER_IMAGE は RUNNER の環境変数に置く（action の `with.env` ではない）。
        # docker-compose が `devcontainer build/up` 実行時にこれを補間し、pull 済みイメージを
        # 全層キャッシュヒットの build として再利用する。
        env:
          DEVCONTAINER_IMAGE: ${{ steps.prebuilt.outputs.image }}
        with:
          configFile: .devcontainer/devcontainer.json
          push: never
          # imageName / cacheFrom は削除（compose-based では効かない。実キャッシュは
          # 上の pull 済み DEVCONTAINER_IMAGE + compose の cache_from 由来）。
          env: |
            # ... 既存の env 行はそのまま ...
          runCmd: |
            # Run Agent
            ./.github/coding-robot/run-action.sh
```

#### (c)（任意・推奨）merge 前検証用に `workflow_dispatch` を追加

`issue_comment` 等のイベントは**常に default branch のワークフロー定義**で実行されるため、
`coding-robot.yml` への変更は merge 前は 🤖 経由で試せない。ブランチ上で「pull → devcontainer 起動」経路を
検証できるよう、`on:` に `workflow_dispatch` を足し、verify 時は agent を起動しない smoke のみにする。

```yaml
on:
  # ... 既存トリガーはそのまま ...
  workflow_dispatch:
    inputs:
      verify_only:
        description: "Only verify the prebuilt-image devcontainer path (no agent run)"
        type: boolean
        default: true
```

job の `if:` を `github.event_name == 'workflow_dispatch' || ( <既存条件> )` にし、
`runCmd` 冒頭で「dispatch かつ verify_only なら smoke して `exit 0`、dispatch かつ非 verify_only なら
issue context が無いので `exit 1`」というガードを入れる。

---

## 5. 検証

1. **prebuild が起動し publish するか（AC: トリガーと publish）**
   `.devcontainer/` を変更して push（または `workflow_dispatch`）し、Devcontainer Prebuild が success、
   ログ末尾で `ghcr.io/<repo>/devcontainer-ci:latest ... Pushed` / `digest: sha256:...` を確認。
   `.devcontainer/` 外（例 README のみ）の push では起動しないことも確認。

2. **coding-robot がフルビルドしないか（AC: 再ビルド無し）**
   prebuild が publish した後に coding-robot を `workflow_dispatch -f verify_only=true`（または実 🤖）で起動し、
   ログで以下を確認:
   - `✅ Prebuilt image pulled`（pull した digest が prebuild の publish digest と一致）
   - `docker compose build` の重い層が **CACHED**
   - フルビルドのマーカー（`Installing Python` / `Downloading Chromium` 等）が **0 件**

3. **digest の一致確認**を必ず行う。「CACHED と出た」だけでなく「**どのイメージを使った CACHED か**」を
   prebuild の publish digest と突き合わせると、古い `:latest` がたまたまヒットしただけ、という偽陽性を排除できる。

---

## 6. 注意・既知の制約

- **bake/重い層の cache key を `paths` で網羅する**（§4.1 の警告）。Dockerfile が `COPY` する pin ファイル
  （例 `frontend/package.json`）が漏れると、その変更時に再 publish されず毎 run 再ビルドになる。
- **コストは「ゼロ化」ではなく「大幅短縮」**。pull（数分）は残る floor。フルビルド（~14 分）と毎 run push が消える分の純減。
- **`coding-robot.yml` / `.devcontainer/*` はローカル改変が乗るファイル**。upstream（masuidrive/github-bots）の
  coding-robot を update で再同期する際、これらを上書きコピーすると本手順の改変が消える。skill core
  （`.github/coding-robot/`）のみを更新する運用なら影響しない。
