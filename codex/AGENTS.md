# Global Agent Instructions

## Pull Request Creation

When creating a pull request, check the repository's pull request template and
write the body following its structure.

### Where to look

Check these in order and use the first one that exists:

1. `.github/PULL_REQUEST_TEMPLATE.md`
2. `.github/pull_request_template.md`
3. The `.md` files under `.github/PULL_REQUEST_TEMPLATE/` (if there are several,
   pick the one closest to the change)
4. `docs/pull_request_template.md`

### How to fill it in

- Keep the template's sections (headings, checklists, comments) as they are.
- Treat `<!-- ... -->` HTML comments as instructions and leave them out of the
  body, unless the template says to keep them.
- Check only the checklist items you actually did; leave the rest unchecked.
- Adding information the template does not ask for is fine, but do not drop or
  rewrite existing sections.
- Only when no template exists, write the body with `## Summary` and
  `## Test plan` sections.

### Implementation notes

- Build the body passed to `gh pr create --body` by reading the template and
  filling in the change.
- Include every section even when the template is long.

## Staging Files

Do not use `git add -A`, `git add .`, or `git add --all`.

Bulk staging can pull in files you did not mean to commit, such as secrets,
build artifacts, or changes outside the current scope. Always stage explicit
paths:

```bash
git add path/to/file1 path/to/file2
```

## Git Commit History

- Unless the user explicitly instructs otherwise, preserve normal Git history by
  creating new commits on top of the current branch.
- Do not amend, squash, reset, or otherwise rewrite existing commits as a default
  workflow. `git commit --amend` is allowed only when the user has clearly and
  specifically asked for an amend.
- Never rewrite a branch other people build on, and never use a bare
  `git push --force`.

### Syncing a pull request branch with its base

When the current branch is a pull request branch that needs to take in changes
from its base branch, including to resolve a conflict, rebase rather than merge:

```
git fetch origin
git rebase origin/<base>
git push --force-with-lease
```

- Do not use `git merge origin/<base>` for this. A merge commit on a long-lived
  PR branch makes the GitHub diff and review history hard to follow.
- If the rebase conflicts across many commits, stop and report to the user
  instead of improvising a squash or a reset.

## Code Search

Do not read whole files while locating code. Find line numbers first, then read only that range.

1. Structure: `ast-grep outline <path>` lists types, functions, and classes with line numbers.
   Go, TypeScript, JavaScript, Python, Java, Rust, and C# have outline rules; Nix, shell, Lua,
   and Scala report `nothing found`, so skip to step 2 for those.
2. Text: `rg -n <pattern>`, with at most `-C 3` when surrounding context is needed.
3. Structure by shape: `ast-grep run -p '<pattern>' -l <lang>` when searching for a code shape
   rather than an identifier. `$NAME` and `$$$` are metavariables.
4. Read: use the line numbers from the steps above to read only that range, with your file
   reader's line offset and limit or with `sed -n 'A,Bp'`.

Read a file in full only when the steps above fail to locate the code, or when rewriting the
whole file.

## Code Comments

Keep code comments concise. Do not comment on things that are obvious from
reading the code.

- Express *what* the code does through the code itself; reserve comments for
  *why* it does it.
- If a variable or function name already conveys intent, a comment restating it
  is unnecessary.
- Avoid redundant preambles and repetition; keep comments to the minimum needed.
