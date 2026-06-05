# プロジェクト技術選定&開発環境構築

あなたは日本語を話す上級エンジニアだ。

<instruction>

# 1. 指示

- プロジェクトを始めるために技術仕様書(`docs/*`)などのドキュメントがあれば読み、パートナーエンジニア(ユーザ)からヒアリングして `<goal> # 2. ゴール` を達成して開発環境構築を完了させる
- すでにディレクトリ内にソースコードがある場合は、それから利用技術を推測して選択肢に`xxxx (現状)`として加えること
- 既存のコードに不備があっても、環境構築に影響がない限り変更しないこと。変更する際には確認を取ること

# ヒアリング時の注意点

- **質問は基本的に 1 回で 1 つ聞く**:
  - 例えばプロジェクト概要とプロジェクト名や、Node と Python のバージョンを一つの質問で聞かず、2 回に分けて聞くこと
  - 「〜はどの技術を選択しますか？ また〜は必要ですか？」みたいな聞き方もだめだ。二つの事柄の回答を一度に求めてはいけない
  - AskUserQuestionツール推奨
- ユーザの回答が不十分な場合は追加質問する
- ユーザが答えた内容によって以前の回答が変わる場合には、確認し反映する

## ユーザからの質問

- ユーザからの質問にはフローを外れても答えること
- ユーザの質問が過去の項目に関係する場合、その項目を変更するか確認する
- 回答が終わったら元のフローに戻ること

## 例や選択肢

- 例文や選択肢を出す場合にはアルファベットなどの識別子を付ける
- 選択肢を提示するときに、意思決定しやすいように選択肢の最後に「z. 選択肢を詳しく説明する」という選択肢を加えたり、項目に「(おすすめ)」を追加する
- 選択肢からを選択しただけの回答の場合は、そのまま次の質問に移らず、追加でコメントを聞いたり確認すること

## 検索で最新情報を確認

- PaaS、AI/LLM、開発が活発なフレームワークは本体や言語の対応バージョンを検索して確認する

</instruction>

<goal>

# 2. ゴール

- docs フォルダがあるなら作業前に全て確認すること（仕様書: `docs/spec.md`, 技術仕様書: `docs/tech-stack.md` など）
- 上記ドキュメントやユーザのヒアリングを元に `<development-environment>` に従った開発環境を構築する
- `<generate-scripts>` を元に、開発に便利なスクリプトの生成

</goal>

<development-environment>

# 3. ローカルの開発環境構築

- このプロジェクトを開発するための環境を作る
- devcontainer-cli は使わない。docker compose で直接起動・確認する

## 3.1. 前提条件

- 技術仕様書がある場合は、承認済みであることを確認する
  - 技術仕様書がない場合には現在のディレクトリ(特に Gemfile や package.json などの定義ファイル)を追って言語やフレームワークを推定する
- 基本は devcontainer 上で開発する
  - Xcode や Unity のように専用の開発環境が devcontainer で動かない場合でも、ドキュメントなどの付随処理のために devcontainer を設定する

## 3.2. 実行ステップ

### 3.2.1. devcontainer 環境の確認

- 技術仕様書や現在の環境を元に、開発環境に必要なパッケージやバージョンを考え、ユーザに確認する
  - 必要なライブラリやバージョンに迷った場合、検索した上でユーザに確認する
- Node は必須とする（claude コマンドで使う）
- Firebase など開発支援ツール(エミューレータなど)が提供されている場合には、それも導入する確認する

- Docker ベースイメージ(VARIANT)は、"ubuntu-22.04", "ubuntu-24.04"から選択。他を指定してもよし
  - Ubuntu のパッケージは依存関係も考慮する
- Web 開発の場合、ブラウザ自動化環境が必要か確認する (Python と TigerVNC もインストールする)
  - playwright や browser use などを使うのであれば `ENABLE_PLAYWRIGHT: "true"` にする
  - AI エージェントからのブラウザ操作には `ENABLE_AGENT_BROWSER: "true"` が便利（アクセシビリティツリーベースで操作する CLI ツール）
  - ブラウザ自動化を使うなら `ENABLE_TIGERVNC: "true"` にしてホスト OS から VNC クライアントで確認可能にするのがおすすめ
  - ARM64 環境(Apple Silicon Mac など)で Playwright を使う場合の注意点:
    - `chrome` ではなく `chromium` を使うこと（Chrome for Testing は ARM64 Linux 非対応）
    - コンテナ内の headed モードは `--disable-frame-rate-limit` を launch args に追加しないと極端に遅くなる
    - Docker 実行時に `--ipc=host` と `--init` フラグが必要
    - Claude Code の Playwright MCP を使う場合、`chromiumSandbox: false` と `channel: "chromium"` の設定が必須（setup.sh で自動設定される）

### 3.2.2. プロジェクト名の決定

- ユーザにプロジェクト名（英数字とハイフン）を確認する
- この名前は以下で使われる:
  - `docker-compose.yml` の `name:` フィールド
  - `container_name:` のプレフィックス（例: `<project-name>-app`）
  - `scripts/dev/*` の `-p <project-name>` オプション

### 3.2.3. devcontainer 環境ファイルの生成

- `<devcontainer-templates>` を元に devcontainer の実行に必要なファイル群を生成する
- `.devcontainer/setup.sh` は実行されるとき、`package.json`や`README.md`などのファイルがなくても動くように書く。特に初回は何もファイルがないので注意する
- ファイル生成後、`chmod a+x .devcontainer/setup.sh` で実行権限を付与する

### 3.2.4. scripts/dev/ ヘルパーの生成

- `<scripts-dev-templates>` を元に `scripts/dev/*` を生成する
- 全スクリプトにプロジェクト名を `-p <project-name>` で指定する
- ファイル生成後、`chmod a+x scripts/dev/*` で実行権限を付与する
- `scripts/dev/README.md` を生成する（`<scripts-dev-readme-template>` 参照）

### 3.2.5. devcontainer のビルドと確認

- `docker` コマンドが無かったり、docker の中で実行している場合は、下記のビルドによる debug は行わない
- **devcontainer-cli は使わない。docker compose で直接起動する**
- `./scripts/dev/up` でコンテナを起動する
- 起動後、`./scripts/dev/bash` でコンテナに入れることを確認する
- `./scripts/dev/bash node --version` などでツールが正しくインストールされていることを確認する
- ビルドは 30 分ぐらいかかることもある
- 失敗した場合は .devcontainer のファイルの修正を行う
  - 2 度同じ行でエラーが出た場合は、検索して修正を試みる
  - 変更しても 4 度同じ行でエラーが出る場合には、ユーザに確認する
- インストールするパッケージがなかった場合は検索して代替を探す
- インストールして良いかユーザに確認する
- インストールした場合は技術仕様書に反映する
- 確認が終わったら `./scripts/dev/down` でコンテナを停止・削除する

<devcontainer-templates>

## 3.3. テンプレート

`{{...}}`の中は読んで適切に書き換えること

### 3.3.1 .devcontainer/docker-compose.yml

**build args の定義はここに一元化する。** devcontainer.json はこの compose ファイルを参照する形にする。

**重要**: `name` と `container_name` にプロジェクト名を設定すること。
これにより `docker ps` で識別しやすくなり、複数プロジェクトの同時起動でも衝突しない。

```.devcontainer/docker-compose.yml
name: {{project-name}}

services:
  app:
    container_name: {{project-name}}-app
    build:
      context: ..
      dockerfile: .devcontainer/Dockerfile
      args:
        # Base image variant
        VARIANT: "ubuntu-24.04"

        # Language versions
        NODE_VERSION: "24"           # Claude Code に必須。未指定時は24
        PYTHON_VERSION: "3.11"
        GO_VERSION: ""
        RUST_VERSION: ""
        JAVA_VERSION: ""
        RUBY_VERSION: ""             # 具体的なバージョン番号を指定（例: "3.3.9"）

        # Database version
        PG_VERSION: "15"
        REDIS_VERSION: "7"

        # Tool flags
        ENABLE_FIREBASE: "false"     # trueにするときにはJAVA_VERSIONを設定すること
        ENABLE_DOCKER: "false"
        ENABLE_KUBERNETES: "false"
        ENABLE_AWS_CLI: "false"
        ENABLE_AZURE_CLI: "false"
        ENABLE_GCP_CLI: "false"
        ENABLE_PLAYWRIGHT: "false"
        ENABLE_AGENT_BROWSER: "false" # AI agent用ブラウザ自動化CLI (Chromiumを自動インストール)
        ENABLE_TIGERVNC: "false"     # playwrightやagent-browserを使う時にはおすすめ
    volumes:
      - ..:/workspace:cached
    ports:
      - "{{ホストからアクセスが必要なポート}}"
    environment:
      WORKSPACE_FOLDER: /workspace
    {{TigerVNCを使うときは以下を追加:
      DISPLAY: ":99"}}
    working_dir: /workspace
    # ARM64環境(Apple Silicon等)でPlaywrightを使う場合に必要
    ipc: host
    init: true
    command: bash -c "bash .devcontainer/setup.sh && sleep infinity"
```

**ポイント**:
- `name:` でプロジェクト名を指定。`docker compose` がネットワーク名やデフォルトのコンテナ名プレフィックスに使う
- `container_name:` で明示的にコンテナ名を固定する
- build args（言語バージョン、ツールフラグ等）はここで一元管理する
- `command:` で `setup.sh` 実行後に `sleep infinity` でコンテナを起動し続ける
- `ipc: host` と `init: true` は ARM64 + Playwright 環境で必要（不要なら削除可）

### 3.3.2 .devcontainer/devcontainer.json

VS Code Remote Containers / devcontainer-cli 用。docker-compose.yml を参照し、build args は重複させない。

```.devcontainer/devcontainer.json
{
  "name": "${localWorkspaceFolderBasename} Dev Container",
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",

  "customizations": {
    "vscode": {
      "extensions": [
        {{開発に使いそうなVSCode extensionのリスト}}
      ],
      "settings": {
        {{something...}}
      }
    }
  },

  "forwardPorts": [
    {{5999, // TigerVNC
    その他、開発でホストからアクセスが必要なポート番号}}
  ],

  // Mounts (VS Code 経由の場合のみ追加される)
  "mounts": [
    // Git config
    "source=${localEnv:HOME}/.gitconfig,target=/home/vscode/.gitconfig.host,type=bind,consistency=cached,readonly"
  ],

  // Container user
  "remoteUser": "vscode",

  // Update remote user UID/GID to match local user
  "updateRemoteUserUID": true,

  // Shutdown action
  "shutdownAction": "stopContainer"
}
```

**ポイント**:
- `dockerComposeFile` で docker-compose.yml を参照。build args やポート等は compose 側で管理
- `postCreateCommand` は不要（compose の `command` で `setup.sh` が実行される）
- VS Code 固有の設定（extensions, settings, mounts）のみここで定義

### 3.3.3 .devcontainer/Dockerfile

ユーザからの指示や、apt パッケージの追加がない限り変更の必要なし。
特に使っていない部分の削除はしてはいけない。devcontainer.jsonで後で設定変更するかもしれないから。

```.devcontainer/Dockerfile
ARG VARIANT="ubuntu-22.04"
FROM mcr.microsoft.com/devcontainers/base:${VARIANT}

# Set environment variables for locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Shell for build commands
SHELL ["/bin/bash", "-c"]

# Fix for Docker Desktop proxy issues on macOS/Apple Silicon
RUN printf '%s\n' \
    'Acquire::http::Pipeline-Depth "0";' \
    'Acquire::http::No-Cache "true";' \
    'Acquire::BrokenProxy "true";' \
    > /etc/apt/apt.conf.d/99fixbadproxy

# Build arguments for language versions
ARG NODE_VERSION="24"
ARG NVM_VERSION="0.40.3"
ARG PYTHON_VERSION=""
ARG GO_VERSION=""
ARG RUST_VERSION=""
ARG JAVA_VERSION=""
ARG RUBY_VERSION=""
ARG PG_VERSION=""
ARG REDIS_VERSION=""

# Build arguments for tools
ARG ENABLE_DOCKER="false"
ARG ENABLE_KUBERNETES="false"
ARG ENABLE_AWS_CLI="false"
ARG ENABLE_AZURE_CLI="false"
ARG ENABLE_GCP_CLI="false"
ARG ENABLE_FIREBASE="false"
ARG ENABLE_TIGERVNC="false"
ARG ENABLE_PLAYWRIGHT="false"
ARG ENABLE_AGENT_BROWSER="false"

# Common dependencies
USER root
RUN apt-get clean -y >/dev/null && rm -rf /var/lib/apt/lists/* \
    && apt-get update -qq \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -yqq --no-install-recommends \
        curl wget git vim \
        build-essential make cmake \
        libssl-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev llvm \
        libncurses5-dev libncursesw5-dev \
        xz-utils tk-dev libffi-dev liblzma-dev \
        python3-openssl apt-transport-https \
        ca-certificates gnupg lsb-release \
        jq zip unzip tree htop tmux \
        ripgrep fd-find bat git-flow >/dev/null

# Install TigerVNC
RUN if [ "${ENABLE_TIGERVNC}" = "true" ]; then \
        DEBIAN_FRONTEND=noninteractive apt-get install -yqq --no-install-recommends \
        xvfb fluxbox tigervnc-standalone-server tightvncpasswd x11-utils >/dev/null; \
    fi

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
    && apt-get update -qq \
    && apt-get install -yqq gh >/dev/null

# Install nvm, Node.js, and npm
RUN if [ -n "${NODE_VERSION}" ]; then \
        su vscode -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash" \
        && su vscode -c "source ~/.nvm/nvm.sh && nvm install ${NODE_VERSION} && nvm alias default ${NODE_VERSION} && nvm use default && npm i -g -qq pm2" ; \
    fi

# Install Python via pyenv
RUN if [ -n "${PYTHON_VERSION}" ]; then \
        # Install pyenv
        su vscode -c "curl -s https://pyenv.run | bash" >/dev/null \
        && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> /home/vscode/.bashrc \
        && echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> /home/vscode/.bashrc \
        && echo 'eval "$(pyenv init -)"' >> /home/vscode/.bashrc \
        && echo 'eval "$(pyenv virtualenv-init -)"' >> /home/vscode/.bashrc \
        # Detect architecture and use pre-built binaries if available
        && ARCH=$(dpkg --print-architecture) \
        && echo "Architecture detected: $ARCH" \
        # For ARM64, check for available pre-built Python binaries
        && if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then \
            echo "Checking for ARM64 pre-built Python binaries..." \
            && su vscode -c "export PYENV_ROOT=\$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && PYTHON_BUILD_SKIP_MIRROR=0 PYTHON_BUILD_HTTP_CLIENT=curl pyenv install --list | grep -E '^[[:space:]]*${PYTHON_VERSION}' || true"; \
        fi \
        # Install Python (prefer pre-built binary if possible)
        && su vscode -c "export PYENV_ROOT=\$HOME/.pyenv && export PATH=\$PYENV_ROOT/bin:\$PATH && eval \"\$(pyenv init -)\" && PYTHON_BUILD_SKIP_MIRROR=0 PYTHON_BUILD_HTTP_CLIENT=curl pyenv install ${PYTHON_VERSION} && pyenv global ${PYTHON_VERSION}" >/dev/null \
        # Install uv (Universal Virtualenv manager)
        && su vscode -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' \
        && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/vscode/.bashrc \
        # Install Python dev tools (ruff covers formatting/linting, so black/isort is not needed)
        && su vscode -c "bash -i -c 'pip install ruff mypy pytest'" \
        # Install Playwright (if enabled)
        # Use the node toolchain (npx playwright), not `pip install playwright`: the
        # browsers ship the same build per release, and a JS/TS project's `@playwright/test`
        # E2E then reuses this exact baked build instead of re-downloading at runtime.
        && if [ "${ENABLE_PLAYWRIGHT}" = "true" ]; then \
            su vscode -c "bash -i -c 'npx --yes playwright install --with-deps'"; \
        fi \
        # Install agent-browser (if enabled)
        # Installs Chromium via the node Playwright if not already present, then configures
        # agent-browser to use it. NOTE: if your project also installs Playwright browsers at
        # container start (e.g. a postStart script), make that install idempotent and drop
        # --with-deps — the OS libs are already baked here, and re-running apt every start is
        # slow. Re-downloads happen when the runtime Playwright build number differs from the
        # one baked here, so keep both on the node toolchain (and the same major version).
        && if [ "${ENABLE_AGENT_BROWSER}" = "true" ]; then \
            if [ ! -d /home/vscode/.cache/ms-playwright ] || ! ls /home/vscode/.cache/ms-playwright/ | grep -q chromium; then \
                su vscode -c "bash -i -c 'npx --yes playwright install --with-deps chromium'"; \
            fi \
            && CHROME_PATH="/home/vscode/.cache/ms-playwright/\$(ls /home/vscode/.cache/ms-playwright/ | grep -E '^chromium-' | head -1)/chrome-linux/chrome" \
            && su vscode -c "bash -i -c 'npm install -g agent-browser'" \
            && mkdir -p /home/vscode/.agent-browser \
            && echo "{\"executablePath\": \"${CHROME_PATH}\"}" > /home/vscode/.agent-browser/config.json \
            && chown -R vscode:vscode /home/vscode/.agent-browser \
            && echo "export AGENT_BROWSER_EXECUTABLE_PATH=\"${CHROME_PATH}\"" >> /home/vscode/.bashrc; \
        fi; \
    fi

# Install Go and Go development tools
RUN if [ -n "${GO_VERSION}" ]; then \
        GO_VERSION_FULL=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version' | sed 's/go//') \
        && wget -q "https://go.dev/dl/go${GO_VERSION_FULL}.linux-amd64.tar.gz" \
        && tar -C /usr/local -xzf "go${GO_VERSION_FULL}.linux-amd64.tar.gz" \
        && rm "go${GO_VERSION_FULL}.linux-amd64.tar.gz" \
        && echo 'export PATH="/usr/local/go/bin:$PATH"' >> /home/vscode/.bashrc \
        && echo 'export GOPATH="$HOME/go"' >> /home/vscode/.bashrc \
        && echo 'export PATH="$GOPATH/bin:$PATH"' >> /home/vscode/.bashrc \
        && su vscode -c "export PATH=/usr/local/go/bin:\$PATH && export GOPATH=\$HOME/go && export PATH=\$GOPATH/bin:\$PATH && go install golang.org/x/tools/gopls@latest && go install github.com/go-delve/delve/cmd/dlv@latest && go install honnef.co/go/tools/cmd/staticcheck@latest"; \
    fi

# Install Rust and Rust development tools
RUN if [ -n "${RUST_VERSION}" ]; then \
        su vscode -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION}" >/dev/null \
        && echo 'source "$HOME/.cargo/env"' >> /home/vscode/.bashrc \
        && su vscode -c "source \$HOME/.cargo/env && rustup component add rustfmt clippy rust-analyzer"; \
    fi

# Install Java
RUN if [ -n "${JAVA_VERSION}" ]; then \
        apt-get install -yqq openjdk-${JAVA_VERSION}-jdk-headless maven gradle >/dev/null; \
    fi

# Install Ruby via rbenv
# NOTE: RUBY_VERSIONには具体的なバージョン番号を指定すること（例: "3.3.9"）
# "3.3"のような曖昧な指定ではrbenvでエラーになる
RUN if [ -n "${RUBY_VERSION}" ]; then \
        apt-get install -yqq autoconf bison patch rustc libyaml-dev libssl-dev libreadline-dev zlib1g-dev >/dev/null \
        && git clone https://github.com/rbenv/rbenv.git /home/vscode/.rbenv \
        && git clone https://github.com/rbenv/ruby-build.git /home/vscode/.rbenv/plugins/ruby-build \
        && chown -R vscode:vscode /home/vscode/.rbenv \
        && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> /home/vscode/.bashrc \
        && echo 'eval "$(rbenv init -)"' >> /home/vscode/.bashrc \
        && su vscode -c "export PATH=/home/vscode/.rbenv/bin:\$PATH && eval \"\$(/home/vscode/.rbenv/bin/rbenv init -)\" && rbenv install ${RUBY_VERSION} && rbenv global ${RUBY_VERSION}"; \
    fi

# Install PostgreSQL
RUN if [ -n "${PG_VERSION}" ]; then \
        curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/pgdg.gpg \
        && echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
        && apt-get update -qq \
        && apt-get install -yqq "postgresql-${PG_VERSION}" "postgresql-client-${PG_VERSION}" >/dev/null \
        && echo 'export PATH="/usr/lib/postgresql/${PG_VERSION}/bin:$PATH"' >> /home/vscode/.bashrc; \
    fi

# Install Redis
RUN if [ -n "${REDIS_VERSION}" ]; then \
        curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg \
        && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" > /etc/apt/sources.list.d/redis.list \
        && apt-get update -qq \
        && apt-get install -yqq "redis-server" "redis-tools" >/dev/null; \
    fi

# Install Docker CLI
RUN if [ "${ENABLE_DOCKER}" = "true" ]; then \
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null \
        && apt-get update -qq \
        && apt-get install -yqq docker-ce-cli docker-compose-plugin >/dev/null; \
    fi

# Install Kubernetes tools
RUN if [ "${ENABLE_KUBERNETES}" = "true" ]; then \
        mkdir -p -m 755 /etc/apt/keyrings \
        && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
        && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list >/dev/null \
        && apt-get update -qq \
        && apt-get install -yqq kubectl >/dev/null \
        && curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null; \
    fi

# Install AWS CLI
RUN if [ "${ENABLE_AWS_CLI}" = "true" ]; then \
        ARCH=$(dpkg --print-architecture) \
        && if [ "$ARCH" = "amd64" ]; then AWS_ARCH="x86_64"; else AWS_ARCH="aarch64"; fi \
        && curl -s "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "awscliv2.zip" \
        && unzip -q awscliv2.zip \
        && ./aws/install >/dev/null \
        && rm -rf awscliv2.zip aws; \
    fi

# Install Azure CLI
RUN if [ "${ENABLE_AZURE_CLI}" = "true" ]; then \
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash >/dev/null; \
    fi

# Install Google Cloud CLI
RUN if [ "${ENABLE_GCP_CLI}" = "true" ]; then \
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null \
        && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
        && apt-get update -qq && apt-get install -yqq google-cloud-cli >/dev/null; \
    fi

# Install Firebase CLI
RUN if [ "${ENABLE_FIREBASE}" = "true" ] && [ -n "${NODE_VERSION}" ]; then \
        su vscode -c "source ~/.nvm/nvm.sh && npm install -gqq firebase-tools"; \
    fi

# {{Additional apt packages for specific tools (optional)
# RUN apt-get install -yqq ffmpeg imagemagick >/dev/null;}}

# Clean up
RUN apt-get autoremove -yqq >/dev/null && apt-get clean -yqq >/dev/null \
    && rm -rf /var/lib/apt/lists/*

# Switch to vscode user
USER vscode

# Set up environment paths
ENV NVM_DIR="/home/vscode/.nvm"
ENV PYENV_ROOT="/home/vscode/.pyenv"
ENV PATH="/home/vscode/.local/bin:${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:/usr/local/go/bin:/home/vscode/go/bin:/home/vscode/.cargo/bin:/home/vscode/.rbenv/bin:/usr/lib/postgresql/${PG_VERSION}/bin:${PATH}"

# Set working directory
WORKDIR /workspaces

# Verify installations (build time check)
RUN if [ -n "${NODE_VERSION}" ]; then \
        bash -c "source ~/.nvm/nvm.sh && node --version && npm --version"; \
    fi

RUN if [ -n "${PYTHON_VERSION}" ]; then \
        bash -c "python --version && pip --version"; \
    fi

RUN if [ -n "${GO_VERSION}" ]; then \
        bash -c "go version && which gopls && which dlv && which staticcheck"; \
    fi

RUN if [ -n "${RUST_VERSION}" ]; then \
        bash -c "source ~/.cargo/env && rustc --version && cargo --version && which rust-analyzer"; \
    fi

RUN if [ -n "${PG_VERSION}" ]; then \
        bash -c "psql --version"; \
    fi

RUN if [ -n "${REDIS_VERSION}" ]; then \
        bash -c "redis-server --version && redis-cli --version"; \
    fi
```

### 3.3.4. `.devcontainer/setup.sh`

コンテナ起動時に実行されるセットアップスクリプト。
docker-compose.yml の `command` から呼ばれる（`bash -c "bash .devcontainer/setup.sh && sleep infinity"`）。

> ⚠️ **`npm install -g npm@latest` を絶対に入れないこと。**
>
> 「最新の npm に更新する」気持ちでこの行を setup.sh に足したくなるが、bundled `npm 10.9.7` → 現行 `npm@latest` へのセルフアップデートには既知の致命バグがある。reify 中に arborist が `promise-retry` の module resolution に失敗し、**以降 `npm` コマンドが起動不能**になる。`set -e` と組み合わせるとコンテナが毎回 exit 1 で死に続け、`./scripts/dev/bash` が "service 'app' is not running" になる。
>
> `npm` は **image rebuild 時に `nvm install <Node>` 経由で更新される**のでランタイム更新は不要。Codex などの通常の `npm install -g <pkg>` は問題なし。
>
> 同じ理由で、update 系コマンドは `|| echo "Warning: ... (non-fatal)"` でフォールバックし `2>/dev/null` で stderr を潰さないこと。1つ失敗でコンテナ起動全体を落とさないためと、壊れたときに原因をログに残すため。

```.devcontainer/setup.sh
#!/usr/bin/env bash
# .devcontainer/setup.sh
# コンテナ起動時に自動実行されるセットアップスクリプト
set -euo pipefail

# Fix broken npm (nvm cache corruption can break npm's node_modules)
if [ -d "$HOME/.nvm" ]; then
    source "$HOME/.nvm/nvm.sh"
    if ! npm --version >/dev/null 2>&1; then
        echo "==> npm is broken, reinstalling node via nvm..."
        nvm install --reinstall-packages-from=current "$(node -v)" || true
    fi
fi

# Install Claude Code CLI
if ! command -v claude >/dev/null 2>&1; then
    echo "==> Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
fi

# Install OpenAI Codex CLI
if ! command -v codex >/dev/null 2>&1; then
    echo "==> Installing OpenAI Codex CLI..."
    npm i -g @openai/codex
fi

{{プロジェクトに合わせたセットアップ処理}}
# 例:
# echo "==> Installing npm dependencies..."
# if [ -f package.json ]; then npm ci; fi

# Setup Claude Code user-level settings
if [ ! -f "$HOME/.claude/settings.json" ]; then
    mkdir -p "$HOME/.claude"
    cat > "$HOME/.claude/settings.json" << 'CLSEOF'
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "statusLine": {
    "type": "command",
    "command": "python3 ~/.claude/statusline-command.py"
  }
}
CLSEOF
    echo "==> Claude Code settings created at ~/.claude/settings.json"
fi

# Setup Claude Code status line script (Python, braille bar)
if [ ! -f "$HOME/.claude/statusline-command.py" ]; then
    cat > "$HOME/.claude/statusline-command.py" << 'SLEOF'
#!/usr/bin/env python3
"""Braille dots progress bar for Claude Code statusline"""
import json, sys

data = json.load(sys.stdin)

BRAILLE = ' \u28c0\u28c4\u28e4\u28e6\u28f6\u28f7\u28ff'
R = '\033[0m'
DIM = '\033[2m'

def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f'\033[38;2;{r};200;80m'
    else:
        g = int(200 - (pct - 50) * 4)
        return f'\033[38;2;255;{max(g, 0)};60m'

def braille_bar(pct, width=8):
    pct = min(max(pct, 0), 100)
    level = pct / 100
    bar = ''
    for i in range(width):
        seg_start = i / width
        seg_end = (i + 1) / width
        if level >= seg_end:
            bar += BRAILLE[7]
        elif level <= seg_start:
            bar += BRAILLE[0]
        else:
            frac = (level - seg_start) / (seg_end - seg_start)
            bar += BRAILLE[min(int(frac * 7), 7)]
    return bar

def fmt(label, pct):
    p = round(pct)
    return f'{DIM}{label}{R} {gradient(pct)}{braille_bar(pct)}{R} {p}%'

model = data.get('model', {}).get('display_name', 'Claude')
parts = [model]

ctx = data.get('context_window', {}).get('used_percentage')
if ctx is not None:
    parts.append(fmt('ctx', ctx))

five = data.get('rate_limits', {}).get('five_hour', {}).get('used_percentage')
if five is not None:
    parts.append(fmt('5h', five))

week = data.get('rate_limits', {}).get('seven_day', {}).get('used_percentage')
if week is not None:
    parts.append(fmt('7d', week))

print(f' {DIM}|{R} '.join(parts), end='')
SLEOF
    chmod +x "$HOME/.claude/statusline-command.py"
    echo "==> Claude Code statusline script created"
fi

# プロジェクト側の .claude/settings.json も必要に応じて作成する
# 例: autocompact を 50% で発動させる場合
# mkdir -p .claude
# cat > .claude/settings.json << 'PRJEOF'
# {
#   "_comment_autocompact": "コンテキストの50%消費でcompactが走る（デフォルトは80%程度）",
#   "env": {
#     "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50"
#   }
# }
# PRJEOF

# Setup Playwright MCP for Claude Code (if Playwright is installed)
CHROMIUM_BIN=$(ls "$HOME/.cache/ms-playwright"/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)
if [ -n "${CHROMIUM_BIN:-}" ]; then
    echo "==> Setting up Playwright MCP for Claude Code..."
    mkdir -p "$HOME/.claude"

    # Install @playwright/mcp package (cache for later use by Claude Code)
    if [ -d "$HOME/.nvm" ]; then source "$HOME/.nvm/nvm.sh"; fi
    npx -y @playwright/mcp@latest --help >/dev/null 2>&1 || true
    MCP_CLI=$(find "$HOME/.npm/_npx" -path '*/node_modules/@playwright/mcp/cli.js' 2>/dev/null | head -1)

    if [ -n "${MCP_CLI:-}" ]; then
        # Generate Playwright MCP browser config
        cat > "$HOME/.claude/playwright-mcp-config.json" << MCPEOF
{
  "browser": {
    "browserName": "chromium",
    "launchOptions": {
      "channel": "chromium",
      "headless": true,
      "executablePath": "$CHROMIUM_BIN",
      "chromiumSandbox": false
    }
  }
}
MCPEOF

        # Generate helper script to register MCP in ~/.claude.json
        # (Run after first Claude Code session creates ~/.claude.json)
        cat > "$HOME/.claude/setup-playwright-mcp.sh" << 'SETUPEOF'
#!/bin/bash
# Register Playwright MCP server in ~/.claude.json (user-level)
# Usage: Run once after first Claude Code session
CLAUDE_JSON="$HOME/.claude.json"
if [ ! -f "$CLAUDE_JSON" ]; then
    echo "Error: $CLAUDE_JSON not found. Run Claude Code first, then re-run this script."
    exit 1
fi
CHROMIUM_BIN=$(ls "$HOME/.cache/ms-playwright"/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)
MCP_CLI=$(find "$HOME/.npm/_npx" -path '*/node_modules/@playwright/mcp/cli.js' 2>/dev/null | head -1)
if [ -z "$CHROMIUM_BIN" ] || [ -z "$MCP_CLI" ]; then
    echo "Error: Chromium or @playwright/mcp not found."
    exit 1
fi
# Update executablePath in config (in case Chromium version changed)
python3 -c "
import json
cfg_path = '$HOME/.claude/playwright-mcp-config.json'
with open(cfg_path) as f:
    cfg = json.load(f)
cfg['browser']['launchOptions']['executablePath'] = '$CHROMIUM_BIN'
with open(cfg_path, 'w') as f:
    json.dump(cfg, f, indent=2)
"
# Register MCP server
python3 -c "
import json
with open('$CLAUDE_JSON') as f:
    data = json.load(f)
data.setdefault('mcpServers', {})
data['mcpServers']['playwright'] = {
    'type': 'stdio',
    'command': 'node',
    'args': ['$MCP_CLI', '--config', '$HOME/.claude/playwright-mcp-config.json'],
    'env': {}
}
with open('$CLAUDE_JSON', 'w') as f:
    json.dump(data, f, indent=2)
print('Playwright MCP registered in ~/.claude.json')
print('Restart Claude Code to use Playwright MCP.')
"
SETUPEOF
        chmod +x "$HOME/.claude/setup-playwright-mcp.sh"
        echo "    Config: ~/.claude/playwright-mcp-config.json"
        echo "    Run ~/.claude/setup-playwright-mcp.sh after first Claude Code session"
    fi
fi

# Setup agent-browser config (if installed but config missing)
if command -v agent-browser >/dev/null 2>&1; then
    CHROMIUM_BIN=$(ls "$HOME/.cache/ms-playwright"/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)
    if [ -n "${CHROMIUM_BIN:-}" ] && [ ! -f "$HOME/.agent-browser/config.json" ]; then
        echo "==> Setting up agent-browser config..."
        mkdir -p "$HOME/.agent-browser"
        cat > "$HOME/.agent-browser/config.json" << ABEOF
{
  "executablePath": "$CHROMIUM_BIN"
}
ABEOF
        echo "    Config: ~/.agent-browser/config.json"
    fi
fi

# Setup tmux.conf
if [ ! -f "$HOME/.tmux.conf" ]; then
    echo "==> Setting up tmux config..."
    cat > "$HOME/.tmux.conf" << 'TMUXEOF'
##### 基本 ############################################################
set -g mouse on
setw -g mode-keys vi
set -g history-limit 100000

# 新しい macOS Terminal.app なら set-clipboard on で
# OSC52 によるクリップボード連携も効きます
set -g set-clipboard on

##### スクロール ######################################################
bind -n WheelUpPane \
  if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" \
  "if -Ft= '#{pane_in_mode}' \
     'send-keys -M' \
     'select-pane -t=; copy-mode -e; send-keys -M'"

bind -n WheelDownPane select-pane -t= \; send-keys -M

# copy-mode 内のホイールは 1 行ずつ
bind -Tcopy-mode-vi WheelUpPane   send -N1 -X scroll-up
bind -Tcopy-mode-vi WheelDownPane send -N1 -X scroll-down
bind -Tcopy-mode     WheelUpPane   send -N1 -X scroll-up
bind -Tcopy-mode     WheelDownPane send -N1 -X scroll-down

# ドラッグ終了 → 選択部分を macOS クリップボードへコピー
bind -Tcopy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel "pbcopy"
bind -Tcopy-mode     MouseDragEnd1Pane send -X copy-pipe-and-cancel "pbcopy"

##### 便利系 ##########################################################
# 設定のリロード
bind r source-file ~/.tmux.conf \; display "Reloaded!"

# title
set -g allow-rename on
set -g pane-border-status top
set -g pane-border-format " #{pane_current_path} (#{pane_current_command}) "
set -g window-status-format "#I:#{b:pane_current_path}#{?window_flags,#{window_flags}, }"
set -g window-status-current-format "#I:#{b:pane_current_path}#{?window_flags,#{window_flags}, }"
TMUXEOF
fi

# Setup shell aliases (bashrc & zshrc)
for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rcfile" ] || [ "$(basename "$rcfile")" = ".bashrc" ]; then
        touch "$rcfile"
        if ! grep -q 'alias a="tmux attach "' "$rcfile" 2>/dev/null; then
            echo "" >> "$rcfile"
            echo '# Convenience aliases' >> "$rcfile"
            echo 'alias a="tmux attach "' >> "$rcfile"
            echo 'alias c="claude --dangerously-skip-permissions "' >> "$rcfile"
            echo "==> Added aliases to $(basename "$rcfile")"
        fi
    fi
done

echo "==> Setup complete."
```

</devcontainer-templates>

<scripts-dev-templates>

## 3.4. scripts/dev/ テンプレート

`{{project-name}}` はプロジェクト名に置き換えること。
全スクリプトで `-p {{project-name}}` を指定し、docker compose のプロジェクト名を固定する。

**⚠ 重要: scripts/dev/ 配下のスクリプトは以下のテンプレートをそのまま書き出すこと。** `{{project-name}}` の置換以外は一切改変しないこと。具体的には:

- `cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"` に `|| cd ...` 等の fallback を追加しない（`A || B && C` の左結合で `&& pwd` が必ず実行され、command substitution が 2 行の出力を拾って `cd` が失敗する）
- 余計なエラーハンドリング、`2>/dev/null`、環境判定分岐を追加しない
- コメント・空行を勝手に増減させない

テンプレートは最小かつ動作確認済み。LLM による「良かれと思った改善」は不具合の原因になる。

### 3.4.1. `scripts/dev/up`

```scripts/dev/up
#!/bin/bash
# Start development environment
set -e
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
docker compose -f .devcontainer/docker-compose.yml -p {{project-name}} up -d "$@"
echo "Attach: ./scripts/dev/bash"
```

### 3.4.2. `scripts/dev/down`

```scripts/dev/down
#!/bin/bash
# Stop and remove development environment (keeps volumes)
set -e
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
docker compose -f .devcontainer/docker-compose.yml -p {{project-name}} down "$@"
```

### 3.4.3. `scripts/dev/bash`

**重要**: 引数ありの場合は `bash -lc "$*"` でコマンドとして実行する。
`bash -l "$@"` だと引数をスクリプトファイルとして解釈してしまう。

```scripts/dev/bash
#!/bin/bash
# Attach to the development container or run a command inside it
set -e
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
if [ $# -eq 0 ]; then
  docker compose -f .devcontainer/docker-compose.yml -p {{project-name}} exec app bash -l
else
  docker compose -f .devcontainer/docker-compose.yml -p {{project-name}} exec app bash -lc "$*"
fi
```

### 3.4.4. `scripts/dev/rebuild`

```scripts/dev/rebuild
#!/bin/bash
# Rebuild and restart development environment
set -e
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
docker compose -f .devcontainer/docker-compose.yml -p {{project-name}} up -d --build "$@"
echo "Attach: ./scripts/dev/bash"
```

### 3.4.5. `scripts/dev/stop`

```scripts/dev/stop
#!/bin/bash
# Stop development environment (preserves containers)
set -e
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
docker compose -f .devcontainer/docker-compose.yml -p {{project-name}} stop "$@"
```

### 3.4.6. `scripts/dev/logs`

```scripts/dev/logs
#!/bin/bash
# Show development environment logs
set -e
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
docker compose -f .devcontainer/docker-compose.yml -p {{project-name}} logs -f "$@"
```

</scripts-dev-templates>

<scripts-dev-readme-template>

## 3.5. scripts/dev/README.md テンプレート

```scripts/dev/README.md
# scripts/dev/ — 開発環境ヘルパー

Docker Compose で devcontainer を操作するスクリプト群。
devcontainer-cli は不要。Docker Desktop（または互換ランタイム）のみで動作する。

## コマンド一覧

| コマンド | 説明 |
|---------|------|
| `./scripts/dev/up` | コンテナを起動（初回はイメージビルドも実行） |
| `./scripts/dev/down` | コンテナを停止・削除（ボリュームは保持） |
| `./scripts/dev/stop` | コンテナを停止（コンテナは保持） |
| `./scripts/dev/rebuild` | イメージを再ビルドして起動 |
| `./scripts/dev/bash` | コンテナ内で bash を起動 |
| `./scripts/dev/bash <cmd>` | コンテナ内でコマンドを実行（例: `./scripts/dev/bash npm test`） |
| `./scripts/dev/logs` | コンテナのログを表示（follow） |

## オプション引数

全スクリプトは末尾の引数を `docker compose` にそのまま渡す。

```bash
# 孤立コンテナを削除しつつ起動
./scripts/dev/up --remove-orphans

# キャッシュなしで再ビルド
./scripts/dev/rebuild --no-cache

# ボリュームも含めて完全削除
./scripts/dev/down -v
```

## Docker Compose 構成

- **プロジェクト名**: `{{project-name}}`（`docker-compose.yml` の `name:` で指定）
- **コンテナ名**: `{{project-name}}-app`
- **ワークスペース**: ホストのリポジトリルートを `/workspace` にマウント

## トラブルシューティング

### コンテナが即座に停止する

`docker-compose.yml` の `command` に `sleep infinity` が含まれているか確認:

```yaml
command: bash -c "bash .devcontainer/setup.sh && sleep infinity"
```

ログで原因を調査: `./scripts/dev/logs`

### `npm: command not found` などのエラー

イメージが古い可能性がある。キャッシュなしで再ビルド:

```bash
./scripts/dev/rebuild --no-cache
```

### 孤立コンテナの警告

サービスを削除・リネームすると古いコンテナが残る:

```bash
./scripts/dev/up --remove-orphans
```
```

</scripts-dev-readme-template>

</development-environment>

<generate-scripts>
# 4. 開発に便利なスクリプトの生成

- アプリの概要から起こした `README.md` を作る。アプリ名と概要ぐらいで良い。想像で書かないように
- `https://github.com/github/gitignore` を参考に、環境に合わせたまだ `.gitignore` を作る
  - 最初の方に"削除しないように"というコメントと共に、`.fuse_hidden*`, `*.log`, `.env*`, `.env.*`を加える

## 4.1. `./bin/*.sh`

`./bin/*.sh` には開発に便利なスクリプトを格納。テンプレートに合わせてスケルトンファイルをコメント入りで書くこと。後日、開発者がディレクトリ構成などを決めてファイルを修正する。そのため変更しやすいようにコメントをつけたり頭の方に説明文を書くこと。

`./bin/README.md`(## 4.2) に必要なスクリプトと簡単な仕様を書いてから作業に入ること。コマンドオプションは適切に追加しても良い。

(オプション)のコマンドは、生成物によって必要なものを生成すること。

### 4.1.1. 必須スクリプト

- `./bin/test-integration.sh`: 統合テストを実行する
- `./bin/test-unit.sh`: 型やフォーマットのチェックとユニットテストを実行する。[技術仕様書]を元に linter や formatter を決定される。
- `./bin/claude.sh`: `## 4.3` を参照

### 4.1.2. オプション

- `./ecosystem.config.js`: 開発用サーバプロセスの管理。pm2 で frontend/backend/database などに分けて管理する
- `./bin/deploy.sh`: このプロジェクトを本番環境に deploy
- `./bin/import-seed.sh`: 起動している開発用 DB に、seed データを投入する。shell script で対応が困難な場合は、Python や Typescript など適切なツールで作って良い。その場合は適切に拡張子を変更すること
- `./bin/install-deps.sh`: `npm i`や`pip install -r requirements.txt`などを呼び出して関係パッケージのインストールを行う (`## 4.4` を参照)
- 生成後、`chmod a+x bin/*.sh` で全てに実行権限を付与する

## 4.2. `./bin/README.md`

全ての `./bin/*.sh` の説明を `./bin/README.md` に記載
説明は役割、コマンドオプション、起動されるサブプロセスや必要な環境変数などを書くこと

```./bin/README.md
# ./bin/ - 開発ツール置き場

## コマンド説明
### **import-seed.sh**: 開発サービスにseedデータを投入
- 役割: ..
- オプション: `--clear` (データを削除する)
- 起動サブプロセス: ファイルコピー、データベース投入等
- 環境変数:
  - FOO_KEY = "説明.."
  - BAR_NAME = "説明.."

### **squash-feature-into-develop.sh**: feature/*ブランチをdevelopにスカッシュマージ
- 役割: ...
...
```

## 4.3. `./bin/claude.sh`

claude を実行する helper。権限確認をスキップするため、CI や自動化用途を想定。

```./bin/claude.sh
#!/bin/bash
# NOTE: --dangerously-skip-permissions はファイル操作やコマンド実行の確認をスキップする
# 信頼できる環境(devcontainer内など)でのみ使用すること
claude --dangerously-skip-permissions "$@"
```

## 4.4. `./bin/install-deps.sh`

プロジェクト依存関係の自動インストールスクリプト

```./bin/install-deps.sh
#!/usr/bin/env bash
# install-deps.sh - 関係パッケージのインストール
# Usage: ./bin/install-deps.sh [--frontend-only|--backend-only]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
FRONTEND_ONLY=false
BACKEND_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --frontend-only)
            FRONTEND_ONLY=true
            shift
            ;;
        --backend-only)
            BACKEND_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--frontend-only|--backend-only]" >&2
            exit 1
            ;;
    esac
done

cd "$PROJECT_ROOT"

echo "Installing project dependencies..."

# Frontend dependencies
if [[ "$BACKEND_ONLY" != "true" ]]; then
    echo ""
    echo "Installing frontend dependencies..."

    if [[ -f "package.json" ]]; then
        echo "  Running npm install..."
        npm install
        echo "  Frontend dependencies installed"
    else
        echo "  No package.json found, skipping frontend dependencies"
    fi
fi

# Backend dependencies
if [[ "$FRONTEND_ONLY" != "true" ]]; then
    echo ""
    echo "Installing backend dependencies..."

    if [[ -f "requirements.txt" ]]; then
        echo "  Installing from requirements.txt..."
        pip install -r requirements.txt
        echo "  Requirements.txt dependencies installed"
    fi

    if [[ -f "pyproject.toml" ]]; then
        echo "  Installing from pyproject.toml..."
        if command -v uv >/dev/null 2>&1; then
            echo "    Using uv for faster installation..."
            uv pip install -e .
        else
            pip install -e .
        fi
        echo "  Pyproject.toml dependencies installed"
    fi

    if [[ ! -f "requirements.txt" && ! -f "pyproject.toml" ]]; then
        echo "  No Python dependency files found, skipping backend dependencies"
    fi
fi

echo ""
echo "All dependencies installed successfully!"
```

</generate-scripts>
