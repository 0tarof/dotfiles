# Global Codex Instructions

## Pull Request Creation

- When creating a pull request, check `${REPO_ROOT}/.github/PULL_REQUEST_TEMPLATE.md` first if it exists, and draft the pull request body according to that template.

## Git Commit History

- Unless the user explicitly instructs otherwise, preserve normal Git history by creating new commits on top of the current branch.
- Do not amend, squash, rebase, reset, force-push, or otherwise rewrite existing commits as a default workflow. `git commit --amend` is allowed only when the user has clearly and specifically asked for an amend.

## Code Search

Do not read whole files while locating code. Find line numbers first, then read only that range.

1. Structure: `ast-grep outline <path>` lists types, functions, and classes with line numbers.
   Go, TypeScript, JavaScript, Python, Java, Rust, and C# have outline rules; Nix, shell, Lua,
   and Scala report `nothing found`, so skip to step 2 for those.
2. Text: `rg -n <pattern>`, with at most `-C 3` when surrounding context is needed.
3. Structure by shape: `ast-grep run -p '<pattern>' -l <lang>` when searching for a code shape
   rather than an identifier. `$NAME` and `$$$` are metavariables.
4. Read: use the line numbers from the steps above with `sed -n 'A,Bp'` to read only that range.

Read a file in full only when the steps above fail to locate the code, or when rewriting the
whole file.
