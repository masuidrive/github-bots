# GitHub Bots Collection

*A collection of GitHub bot scripts for @masuidrive's repositories*

**[日本語は下記](#日本語)**

---

## 🚀 Quick Install

The easiest way to install a bot is to run:
```bash
claude "Read https://masuidrive.jp/bots and execute it"
```

This will guide you through the installation process.

---

## 🤖 Available Bots

### claude-coding-robot

An AI-powered coding assistant that runs on your repository's devcontainer environment. Add `:robot:` (🤖) to Issues or Pull Request comments, and the bot will automatically handle the request.

**Example use case:**
When someone reports a bug in an Issue, just comment "Please investigate and fix this 🤖" - the bot will analyze the issue, create a fix, run tests, and provide a link to create a Pull Request.

**Installation:**
Open Claude Code on your local machine and ask:
```
Read and execute https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/setup.md
```

📖 [AI Setup](./coding-robot/README.md) (asks Claude/Codex, sets the secret via `gh`) | [Setup Guide](./coding-robot/setup.md) | 🔧 [Configuration](./coding-robot/.github/coding-robot/system.md)

**Optional — devcontainer prebuild (speed & cost):** with a compose-based devcontainer the bot rebuilds the whole image on every run (~14 min/run). Pre-build the image once and have the bot pull it instead. See 📖 [Prebuild Setup](./setup-prebuild.md).

### setup-devcontainer

A devcontainer setup bot that interviews you about your project's tech stack and automatically generates a complete devcontainer environment. It creates `Dockerfile`, `devcontainer.json`, lifecycle scripts, and utility shell scripts tailored to your project.

**Installation:**
Open Claude Code on your local machine and ask:
```
Read and execute https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/setup-devcontainer.md
```

📖 [Setup Script](./setup-devcontainer.md)

### PDH (Product Delivery Hierarchy)

A three-tier framework (Product Brief → Epic → Ticket) for structuring product work. Designed for both humans and coding agents like Claude Code.

**Installation:**
Open Claude Code on your local machine and ask:
```
Read https://github.com/masuidrive/pdh README and set up PDH in this project.
```

🔗 [PDH Repository](https://github.com/masuidrive/pdh)

---

## 📝 License

Apache License 2.0 - Feel free to use and modify for your own projects.

---

<a name="日本語"></a>

# GitHub Bots コレクション

*@masuidrive のリポジトリ用 GitHub bot スクリプト集*

---

## 🚀 簡単インストール

このbotをインストールするには、以下のコマンドを実行するのが一番手軽です：
```bash
claude "https://masuidrive.jp/bots を読んで実行して"
```

インストールに導いてくれます。

---

## 🤖 提供しているBot

### claude-coding-robot

リポジトリのdevcontainer環境上で動作するAI搭載コーディングアシスタント。IssuesやPull Requestのコメントに `:robot:` (🤖) を書くと、そのリクエストを自動的に処理してくれます。

**使用例：**
誰かがIssueでバグを報告したら、コメントに「確認して修正して 🤖」と書くだけ。botがバグを分析し、修正を作成し、テストを実行して、Pull Requestを作成するリンクを送ってくれます。

**インストール方法：**
手元のClaude Code上で以下のようにお願いしてみてください：
```
https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/coding-robot/setup.md を読んで実行して
```

📖 [AI セットアップ](./coding-robot/README.md)（Claude/Codex を聞いて `gh` でシークレット設定） | [セットアップガイド](./coding-robot/setup.md) | 🔧 [設定ファイル](./coding-robot/.github/coding-robot/system.md)

**任意 — devcontainer 事前ビルド（速度・コスト）：** compose-based の devcontainer では bot が毎 run イメージを丸ごと再ビルドします（~14 分/run）。イメージを一度だけ事前ビルドして bot は pull するだけにできます。📖 [事前ビルド手順](./setup-prebuild.md) を参照。

### setup-devcontainer

devcontainer 設定 bot。プロジェクトの技術スタックをヒアリングし、devcontainer 環境を自動生成します。`Dockerfile`、`devcontainer.json`、ライフサイクルスクリプト、開発用シェルスクリプトをプロジェクトに合わせて作成します。

**インストール方法：**
手元のClaude Code上で以下のようにお願いしてみてください：
```
https://raw.githubusercontent.com/masuidrive/github-bots/refs/heads/main/setup-devcontainer.md を読んで実行して
```

📖 [セットアップスクリプト](./setup-devcontainer.md)

### PDH (Product Delivery Hierarchy)

プロダクト開発を3階層（Product Brief → Epic → Ticket）で構造化するフレームワーク。人間とClaude Codeなどのコーディングエージェントの両方で利用可能。

**インストール方法：**
手元のClaude Code上で以下のようにお願いしてみてください：
```
https://github.com/masuidrive/pdh の README を読んで、このプロジェクトに PDH を導入して
```

🔗 [PDH リポジトリ](https://github.com/masuidrive/pdh)

---

## 📝 ライセンス

Apache License 2.0 - ご自由にお使いください。
