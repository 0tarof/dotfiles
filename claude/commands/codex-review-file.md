---
description: OpenAI Codex (GPT-5) を使用して特定のファイルをレビュー
argument-hint: <file-path>
---

指定されたファイルを OpenAI Codex CLI (GPT-5) を使用してレビューします。

レビュー対象ファイル: $ARGUMENTS

以下の手順に従ってください：

1. $ARGUMENTS にファイルパスが指定されていない場合は、レビューするファイルを尋ねます。

2. 指定されたファイルの内容を読み取ります。

3. ファイル内容を含めて以下の Bash コマンドを実行します：
   ```bash
   codex exec -m "gpt-5-codex" "Please review the following Go code file with focus on:
   1. Code quality and Go best practices
   2. Performance optimization opportunities (memory, CPU, latency)
   3. Potential bugs or edge cases
   4. Architecture and design patterns
   5. Suggestions for improvement

   Context: This is part of a high-performance SSP ad server (Go + Echo framework) with strict latency requirements.

   **IMPORTANT: Please respond in Japanese.**

   File: <FILE_PATH>

   [INSERT FILE CONTENT HERE]"
   ```

4. Codex のレビュー結果を日本語で表示します。

5. 主要な発見事項と実行可能な推奨事項を日本語で要約します。

注意: ファイルが存在しない場合は、その旨を通知してください。