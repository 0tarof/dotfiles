---
description: Create a PR with proper preparation and commit
---

Create a pull request following the complete workflow from preparation to PR creation.

**IMPORTANT: Please respond to the user in Japanese.**

Follow these steps:

1. **Understand the changes**
   - Run `git status` to see all modified and untracked files
   - Run `git diff` to see staged and unstaged changes
   - Run `git log -5 --oneline` to understand recent commit history

2. **Pre-commit preparation**
   - Check CLAUDE.md in the repository root for any project-specific requirements
   - If there are mock generation scripts, tests, linters, or build steps mentioned, execute them
   - Address any errors or failures before proceeding
   - For this dotfiles repository specifically:
     - If Brewfile was modified, run `bin/brew-check` to verify
     - If scripts in bin/ were modified, ensure they have proper error handling
     - Test any modified scripts if feasible

3. **Stage and commit changes**
   - Use `git add` with EXPLICIT file paths (e.g., `git add path/to/file1.txt path/to/file2.txt`)
   - NEVER use `git add .` or `git add -A`
   - Analyze all changes and create a descriptive commit message following the repository's style
   - Commit with the message ending with:
     ```
     🤖 Generated with [Claude Code](https://claude.com/claude-code)

     Co-Authored-By: Claude <noreply@anthropic.com>
     ```

4. **Push to origin**
   - Push the current branch to origin with `git push -u origin <branch-name>`
   - If the branch doesn't exist on remote, it will be created

5. **Create pull request**
   - Check if `.github/PULL_REQUEST_TEMPLATE.md` exists in the repository
   - If template exists, use it as the base for the PR body
   - If no template, create a concise PR description with:
     - Summary: Brief overview of changes (1-3 bullet points)
     - Changes: List of main modifications
     - Testing: How the changes were tested (if applicable)
   - Use `gh pr create` with appropriate title and body
   - Add the following footer to the PR body:
     ```
     🤖 Generated with [Claude Code](https://claude.com/claude-code)
     ```
   - Return the PR URL to the user

**Important notes:**
- DO NOT skip any preparation steps mentioned in CLAUDE.md
- DO NOT proceed if tests or checks fail
- ALWAYS stage files explicitly by path
- ALWAYS communicate with the user in Japanese
- If unsure about any step, ask the user for clarification in Japanese
