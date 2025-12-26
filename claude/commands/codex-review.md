---
description: OpenAI Codex (GPT-5) を使用してブランチの変更をレビュー
---

現在のブランチのコード変更を親ブランチと比較して、OpenAI Codex CLI (GPT-5) を使用してレビューします。

以下の手順に従ってください：

1. 親ブランチを特定します（通常は `develop`）。git コマンドを使用して特定するか、デフォルトで `develop` を使用します。

2. 親ブランチと現在のブランチの差分を取得します：`git diff <parent>...HEAD`

3. 差分内容を含めて以下の Bash コマンドを実行します：
   ```bash
   codex exec -m "gpt-5-codex" "Please review the following code changes with focus on:
   1. Code quality and Go best practices
   2. Performance (memory efficiency, latency, throughput)
   3. Potential issues or bugs
   4. Suggestions for improvement

   Context: This is a high-performance SSP (Supply Side Platform) ad server built with Go and Echo framework.

   **IMPORTANT: Please respond in Japanese.**

   Changes:
   [INSERT DIFF HERE]"
   ```

4. Codex のレビュー結果を日本語で表示します。

5. 必要に応じて、主要な発見事項を日本語で要約します。

注意: 差分が空の場合は、レビューする変更がないことを通知してください。