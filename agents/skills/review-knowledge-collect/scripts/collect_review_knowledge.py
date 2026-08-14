#!/usr/bin/env python3
"""Collect one PR review lesson as a Markdown note."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path


CATEGORY_KEYWORDS = {
    "security": ["secret", "token", "auth", "permission", "xss", "csrf", "sql injection"],
    "api-contracts": ["api", "contract", "compat", "payload", "schema", "serializer"],
    "tests": ["test", "coverage", "fixture", "snapshot", "regression"],
    "data-integrity": ["migration", "transaction", "idempotent", "duplicate", "null", "nil"],
    "concurrency": ["race", "lock", "parallel", "goroutine", "thread", "async"],
    "performance": ["n+1", "latency", "memory", "cache", "query", "timeout"],
    "observability": ["log", "metric", "trace", "alert", "dashboard"],
    "frontend-ux": ["ui", "ux", "accessibility", "a11y", "responsive", "focus"],
    "maintainability": ["refactor", "naming", "duplication", "complexity", "abstraction"],
    "dependencies": ["dependency", "version", "package", "lockfile", "supply chain"],
    "release-ops": ["deploy", "rollback", "release", "feature flag", "migration order"],
    "process": ["review", "bot", "handoff", "ownership", "checklist"],
}


def default_root() -> Path:
    return Path.home() / "sandbox" / "review-knowledge"


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value[:80].strip("-") or "review-lesson"


def normalize_tags(values: list[str]) -> list[str]:
    tags: list[str] = []
    for value in values:
        for part in value.split(","):
            tag = slugify(part)
            if tag and tag not in tags:
                tags.append(tag)
    return tags


def infer_category(title: str, body: str, tags: list[str]) -> str:
    haystack = " ".join([title, body, " ".join(tags)]).lower()
    for category, keywords in CATEGORY_KEYWORDS.items():
        if any(keyword in haystack for keyword in keywords):
            return category
    return "correctness"


def read_body(args: argparse.Namespace) -> str:
    if args.body_file:
        return Path(args.body_file).expanduser().read_text(encoding="utf-8").strip()
    if args.body is not None:
        return args.body.strip()
    if not sys.stdin.isatty():
        return sys.stdin.read().strip()
    return ""


def frontmatter(data: dict[str, object]) -> str:
    lines = ["---"]
    for key, value in data.items():
        if isinstance(value, list):
            lines.append(f"{key}: {json.dumps(value, ensure_ascii=False)}")
        else:
            lines.append(f"{key}: {json.dumps(value, ensure_ascii=False)}")
    lines.append("---")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(default_root()), help="Knowledge root directory")
    parser.add_argument("--title", required=True, help="Short lesson title")
    parser.add_argument("--category", help="Review category")
    parser.add_argument("--tags", action="append", default=[], help="Comma-separated tags; repeatable")
    parser.add_argument("--source", default="", help="PR URL, repo#PR, file path, or other source")
    parser.add_argument(
        "--confidence",
        choices=["low", "medium", "high"],
        default="medium",
        help="Confidence in the lesson",
    )
    parser.add_argument("--body", help="Markdown body for the lesson")
    parser.add_argument("--body-file", help="Read Markdown body from this file")
    args = parser.parse_args()

    root = Path(args.root).expanduser()
    storage = root / "storage"
    storage.mkdir(parents=True, exist_ok=True)

    body = read_body(args)
    tags = normalize_tags(args.tags)
    category = slugify(args.category) if args.category else infer_category(args.title, body, tags)
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    note_id = f"{dt.datetime.now().strftime('%Y%m%d-%H%M%S')}-{slugify(args.title)}"
    path = storage / f"{note_id}.md"

    metadata = {
        "id": note_id,
        "created_at": now,
        "updated_at": now,
        "category": category,
        "tags": tags,
        "source": args.source,
        "confidence": args.confidence,
        "status": "active",
    }

    content = [
        frontmatter(metadata),
        "",
        f"# {args.title.strip()}",
        "",
        "## Knowledge",
        "",
        body or "TODO: Add the reusable review lesson.",
        "",
        "## Review Prompt",
        "",
        "- What signal should reviewers look for?",
        "- What failure mode does this prevent?",
        "- What test or evidence would confirm the concern?",
        "",
    ]
    path.write_text("\n".join(content), encoding="utf-8")
    print(path)
    print(f"category={category}")
    print(f"tags={','.join(tags)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
