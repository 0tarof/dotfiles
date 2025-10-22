---
description: Review branch changes using OpenAI Codex (GPT-5)
---

Review the code changes in the current branch against the parent branch using OpenAI Codex CLI with GPT-5.

Follow these steps:

1. Determine the parent branch (usually `develop`). Use git commands to identify it, or default to `develop`.

2. Get the diff between the parent branch and current branch using: `git diff <parent>...HEAD`

3. Execute the following Bash command with the diff content:
   ```bash
   codex exec -m "gpt-5" "Please review the following code changes with focus on:
   1. Code quality and Go best practices
   2. Performance (memory efficiency, latency, throughput)
   3. Potential issues or bugs
   4. Suggestions for improvement

   Context: This is a high-performance SSP (Supply Side Platform) ad server built with Go and Echo framework.

   **IMPORTANT: Please respond in Japanese.**

   Changes:
   [INSERT DIFF HERE]"
   ```

4. Display the Codex review results to me in Japanese.

5. Summarize the key findings if needed in Japanese.

Note: If the diff is empty, inform me that there are no changes to review.