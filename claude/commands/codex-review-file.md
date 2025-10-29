---
description: Review a specific file using OpenAI Codex (GPT-5)
argument-hint: <file-path>
---

Review the specified file using OpenAI Codex CLI with GPT-5.

File to review: $ARGUMENTS

Follow these steps:

1. If no file path was provided in $ARGUMENTS, ask me which file to review.

2. Read the content of the specified file.

3. Execute the following Bash command with the file content:
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

4. Display the Codex review results to me in Japanese.

5. Summarize the key findings and actionable recommendations in Japanese.

Note: If the file doesn't exist, inform me.