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

**Note:** Coding Robot uses `devcontainer-cli` to build and run the container, but does **not** execute `postCreateCommand` or `postStartCommand`. If your devcontainer relies on these lifecycle hooks to install tools or set up the environment, those steps will not run during bot execution. Ensure all required tools are installed in the Dockerfile itself.

📖 [Setup Guide](./coding-robot/setup.md) | 🔧 [Configuration](./coding-robot/.github/coding-robot/system.md)

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

**注意:** Coding Robotは `devcontainer-cli` でコンテナをビルド・実行しますが、`postCreateCommand` や `postStartCommand` は**実行されません**。これらのライフサイクルフックでツールのインストールや環境構築を行っている場合、bot実行時にはそれらのステップは実行されません。必要なツールはすべてDockerfile内でインストールしてください。

📖 [セットアップガイド](./coding-robot/setup.md) | 🔧 [設定ファイル](./coding-robot/.github/coding-robot/system.md)

---

## 📝 ライセンス

Apache License 2.0 - ご自由にお使いください。
