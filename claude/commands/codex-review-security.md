---
description: Security-focused review of branch changes using OpenAI Codex (GPT-5)
---

Conduct a security-focused review of code changes in the current branch using OpenAI Codex CLI with GPT-5.

Follow these steps:

1. Determine the parent branch (usually `develop`). Use git commands to identify it, or default to `develop`.

2. Get the diff between the parent branch and current branch using: `git diff <parent>...HEAD`

3. Execute the following Bash command with the diff content:
   ```bash
   codex exec -m "gpt-5" "Please conduct a thorough SECURITY REVIEW of the following code changes. Focus on:

   🔐 **Critical Security Areas:**
   1. **SQL Injection**: Check for raw SQL queries, ensure XORM query builder usage
   2. **Authentication/Authorization**: Verify Supplier ID validation, access controls
   3. **Input Validation**: Check all user inputs are properly validated and sanitized
   4. **Secrets & Credentials**: Ensure no hardcoded keys, tokens, or passwords
   5. **Data Privacy**: GDPR/CCPA compliance, PII handling, Do Not Track
   6. **Cryptography**: Secure algorithms, proper key management
   7. **Error Handling**: No sensitive data leakage in errors/logs
   8. **Injection Attacks**: Command injection, path traversal, XSS potential

   Context: This is a high-traffic SSP ad server handling real-time bidding with OpenRTB. Security is critical due to:
   - Financial transactions
   - Privacy regulations (GDPR/CCPA)
   - High-value target for attacks
   - AWS production environment

   For each finding, provide:
   - Severity: CRITICAL / HIGH / MEDIUM / LOW
   - Location: File and line reference
   - Issue: What the security concern is
   - Impact: Potential consequences
   - Recommendation: How to fix

   **IMPORTANT: Please respond in Japanese.**

   Changes:
   [INSERT DIFF HERE]"
   ```

4. Display the security review results to me in Japanese with severity levels highlighted.

5. Summarize critical and high severity findings in Japanese.

Note: Always address CRITICAL and HIGH severity findings before merging.