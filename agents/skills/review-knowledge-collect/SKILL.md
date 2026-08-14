---
name: review-knowledge-collect
description: Capture PR/code review lessons into a local Markdown knowledge base and organize them into grouped review manifests. Use when the user asks to save review know-how, collect PR review viewpoints, remember a review lesson, update an evolving review skill, organize `~/sandbox/review-knowledge/storage`, generate manifests under `~/sandbox/review-knowledge/manifests`, or set up/operate periodic review-knowledge maintenance.
---

# Review Knowledge Collect

Build an evolving local review knowledge base from concrete PR review experience.

Use Japanese with the user unless they ask otherwise.

## Paths

Default root:

```bash
${REVIEW_KNOWLEDGE_ROOT:-$HOME/sandbox/review-knowledge}
```

Default subdirectories:

```bash
storage/    # raw Markdown notes, one lesson per file
manifests/  # regenerated grouped review viewpoints
```

Create missing directories when collecting or organizing.

## Bundled Scripts

Use these scripts relative to the skill directory:

```bash
scripts/collect_review_knowledge.py
scripts/organize_review_knowledge.py
```

When using this repository source directly:

```bash
.agents/skills/review-knowledge-collect/scripts/collect_review_knowledge.py
.agents/skills/review-knowledge-collect/scripts/organize_review_knowledge.py
```

When installed by Home Manager:

```bash
${CODEX_HOME:-$HOME/.codex}/skills/review-knowledge-collect/scripts/collect_review_knowledge.py
${CODEX_HOME:-$HOME/.codex}/skills/review-knowledge-collect/scripts/organize_review_knowledge.py
```

## Collect Workflow

1. Capture one reusable review lesson per note.
2. Preserve concrete evidence: PR URL, file path, bot comment, bug pattern, or review context when available.
3. Separate facts from inference. Mark uncertain lessons with lower confidence.
4. Avoid storing secrets, credentials, private tokens, customer data, or large proprietary snippets. Summarize sensitive code instead.
5. Prefer durable review viewpoints over one-off project trivia.
6. Run the collector:

```bash
<skill-dir>/scripts/collect_review_knowledge.py \
  --title "Validate nil/empty behavior before changing API payloads" \
  --category api-contracts \
  --tags api,compatibility,regression \
  --source "owner/repo#123" \
  --confidence high \
  --body "Changing omitted fields into explicit empty values can break clients. Review serializers, generated clients, and compatibility tests together."
```

If the user gives only a rough lesson, still save it. Use `--confidence low` and keep the note honest about what is known.

## Organize Workflow

Run:

```bash
<skill-dir>/scripts/organize_review_knowledge.py
```

The organizer reads Markdown notes from `storage/` and regenerates:

- `manifests/index.md`: category index and tag summary
- `manifests/<category>.md`: grouped review viewpoints for each category with source links
- `manifests/tags.md`: tag-oriented lookup

The organizer is intentionally deterministic and safe to run daily. It does not edit raw storage notes.

## Category Guidance

Use an existing category when possible:

- `correctness`
- `api-contracts`
- `tests`
- `security`
- `data-integrity`
- `concurrency`
- `performance`
- `observability`
- `frontend-ux`
- `maintainability`
- `dependencies`
- `release-ops`
- `process`

If no category fits, use a concise lowercase hyphenated category. The organizer will still include it.

## Periodic Maintenance

When the user asks for a recurring task, use Codex automations via `automation_update`; do not emit raw cron directives.

For a detached daily maintenance job, create a cron automation against this dotfiles workspace with a prompt like:

```text
Use $review-knowledge-collect to organize the review knowledge base. Read Markdown notes under /Users/a14993/sandbox/review-knowledge/storage and regenerate grouped manifests under /Users/a14993/sandbox/review-knowledge/manifests. Use the bundled organizer script when available. Report the generated manifest files and any malformed notes.
```

Prefer not to commit `~/sandbox/review-knowledge` content unless the user explicitly asks to version it somewhere.

## Output Style

After collecting, report the created note path and the inferred category/tags.

After organizing, report the manifest files generated and the number of source notes processed.
