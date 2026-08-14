#!/usr/bin/env python3
"""Regenerate review-knowledge manifests from Markdown storage notes."""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import re
from pathlib import Path


CATEGORY_ORDER = [
    "correctness",
    "api-contracts",
    "tests",
    "security",
    "data-integrity",
    "concurrency",
    "performance",
    "observability",
    "frontend-ux",
    "maintainability",
    "dependencies",
    "release-ops",
    "process",
]

CATEGORY_TITLES = {
    "api-contracts": "API Contracts",
    "data-integrity": "Data Integrity",
    "frontend-ux": "Frontend UX",
    "release-ops": "Release Ops",
}


def default_root() -> Path:
    return Path.home() / "sandbox" / "review-knowledge"


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value or "uncategorized"


def parse_scalar(value: str):
    value = value.strip()
    if value.startswith("["):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return []
    if value.startswith('"') and value.endswith('"'):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value.strip('"')
    return value


def parse_note(path: Path, storage: Path) -> dict[str, object]:
    text = path.read_text(encoding="utf-8")
    meta: dict[str, object] = {}
    body = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            raw_meta = text[4:end].splitlines()
            body = text[end + 5 :]
            for line in raw_meta:
                if ":" not in line:
                    continue
                key, value = line.split(":", 1)
                meta[key.strip()] = parse_scalar(value)

    title = path.stem
    for line in body.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break

    summary_lines = []
    in_knowledge = False
    for line in body.splitlines():
        stripped = line.strip()
        if stripped == "## Knowledge":
            in_knowledge = True
            continue
        if stripped.startswith("## ") and stripped != "## Knowledge":
            if in_knowledge:
                break
            continue
        if not in_knowledge:
            continue
        if not stripped or stripped.startswith("#") or stripped == "---":
            continue
        summary_lines.append(stripped)
        if len(summary_lines) >= 2:
            break

    category = slugify(str(meta.get("category") or "correctness"))
    tags = meta.get("tags") or []
    if not isinstance(tags, list):
        tags = [str(tags)]

    return {
        "path": path,
        "relative_path": path.relative_to(storage.parent).as_posix(),
        "title": title,
        "summary": " ".join(summary_lines) or "No summary available.",
        "category": category,
        "tags": [slugify(str(tag)) for tag in tags if str(tag).strip()],
        "source": str(meta.get("source") or ""),
        "confidence": str(meta.get("confidence") or "medium"),
        "created_at": str(meta.get("created_at") or ""),
    }


def title_for_category(category: str) -> str:
    return CATEGORY_TITLES.get(category, category.replace("-", " ").title())


def sort_categories(categories: list[str]) -> list[str]:
    rank = {category: index for index, category in enumerate(CATEGORY_ORDER)}
    return sorted(categories, key=lambda category: (rank.get(category, 999), category))


def note_link(note: dict[str, object]) -> str:
    return f"../{note['relative_path']}"


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def build_index(notes: list[dict[str, object]], grouped: dict[str, list[dict[str, object]]], generated_at: str) -> str:
    tag_counts = collections.Counter(tag for note in notes for tag in note["tags"])
    lines = [
        "# Review Knowledge Manifests",
        "",
        f"Generated: {generated_at}",
        f"Source notes: {len(notes)}",
        "",
        "## Categories",
        "",
    ]
    for category in sort_categories(list(grouped)):
        title = title_for_category(category)
        lines.append(f"- [{title}]({category}.md): {len(grouped[category])} notes")

    lines.extend(["", "## Top Tags", ""])
    if tag_counts:
        for tag, count in tag_counts.most_common(30):
            lines.append(f"- `{tag}`: {count}")
    else:
        lines.append("- No tags yet.")
    return "\n".join(lines)


def build_category(category: str, notes: list[dict[str, object]], generated_at: str) -> str:
    lines = [
        f"# {title_for_category(category)}",
        "",
        f"Generated: {generated_at}",
        f"Source notes: {len(notes)}",
        "",
        "## Review Viewpoints",
        "",
    ]
    for note in sorted(notes, key=lambda item: str(item["title"]).lower()):
        tags = ", ".join(f"`{tag}`" for tag in note["tags"]) or "none"
        source = f" Source: {note['source']}." if note["source"] else ""
        lines.extend(
            [
                f"### [{note['title']}]({note_link(note)})",
                "",
                f"- Tags: {tags}",
                f"- Confidence: {note['confidence']}.{source}",
                f"- Takeaway: {note['summary']}",
                "",
            ]
        )
    return "\n".join(lines)


def build_tags(notes: list[dict[str, object]], generated_at: str) -> str:
    by_tag: dict[str, list[dict[str, object]]] = collections.defaultdict(list)
    for note in notes:
        for tag in note["tags"]:
            by_tag[tag].append(note)

    lines = ["# Review Knowledge Tags", "", f"Generated: {generated_at}", ""]
    if not by_tag:
        lines.append("No tags yet.")
        return "\n".join(lines)

    for tag in sorted(by_tag):
        lines.extend([f"## `{tag}`", ""])
        for note in sorted(by_tag[tag], key=lambda item: str(item["title"]).lower()):
            lines.append(f"- [{note['title']}]({note_link(note)}) ({note['category']})")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(default_root()), help="Knowledge root directory")
    args = parser.parse_args()

    root = Path(args.root).expanduser()
    storage = root / "storage"
    manifests = root / "manifests"
    storage.mkdir(parents=True, exist_ok=True)
    manifests.mkdir(parents=True, exist_ok=True)

    notes = [parse_note(path, storage) for path in sorted(storage.glob("*.md"))]
    grouped: dict[str, list[dict[str, object]]] = collections.defaultdict(list)
    for note in notes:
        grouped[str(note["category"])].append(note)

    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    write(manifests / "index.md", build_index(notes, grouped, generated_at))
    write(manifests / "tags.md", build_tags(notes, generated_at))
    for category, category_notes in grouped.items():
        write(manifests / f"{category}.md", build_category(category, category_notes, generated_at))

    print(f"notes={len(notes)}")
    print(f"manifests={manifests}")
    for path in sorted(manifests.glob("*.md")):
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
