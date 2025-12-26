---
description: OpenAI Codex (GPT-5) を使用したブランチ変更のセキュリティレビュー
---

現在のブランチのコード変更に対して、OpenAI Codex CLI (GPT-5) を使用してセキュリティに焦点を当てたレビューを実施します。

以下の手順に従ってください：

1. 親ブランチを特定します（通常は `develop`）。git コマンドを使用して特定するか、デフォルトで `develop` を使用します。

2. 親ブランチと現在のブランチの差分を取得します：`git diff <parent>...HEAD`

3. 差分内容を含めて以下の Bash コマンドを実行します：
   ```bash
   codex exec -m "gpt-5-codex" "Please conduct a thorough SECURITY REVIEW of the following code changes. Focus on:

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

4. セキュリティレビューの結果を、重要度レベルを強調しながら日本語で表示します。

5. CRITICAL および HIGH 重要度の発見事項を日本語で要約します。

注意: マージ前に必ず CRITICAL および HIGH 重要度の問題に対処してください。