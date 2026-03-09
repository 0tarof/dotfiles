---
name: codex-review
description: OpenAI Codex (GPT-5) を使用してブランチの変更をレビュー。「codexレビュー」「ブランチレビュー」「変更レビュー」などの依頼で起動。
allowed-tools:
  - Read
  - Bash
model: claude-haiku-4-5-20251001
user-invocable: true
---

# Codex Review スキル

`codex review` コマンドを使用して、現在のブランチのコード変更をレビューします。

**IMPORTANT: このスキルを使用する際は、特に指定が無い限り日本語でユーザーとコミュニケーションを取ってください。**

## ワークフロー

### 1. 親ブランチの特定

まず親ブランチを特定します。以下のコマンドを実行してください。

```bash
# 現在のブランチを確認
git branch --show-current

# マージ元のブランチを推測（develop, main, master のいずれか）
git branch -r | grep -E 'origin/(develop|main|master)$' | head -1
```

親ブランチが不明な場合は、ユーザーに確認してください。

### 2. codex review でレビュー実行

特定した親ブランチ名を `<PARENT_BRANCH>` に置き換えて、以下のコマンドを実行します。

```bash
codex review --base <PARENT_BRANCH>
```

### 3. 結果の表示

レビュー結果を日本語で表示します。必要に応じて主要な発見事項を要約します。

## 注意事項

- 差分が空の場合は、レビューする変更がないことを通知してください
- Codex CLI (`codex`) がインストールされていない場合は `npm install -g @openai/codex` を案内
