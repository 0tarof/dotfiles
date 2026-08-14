#!/usr/bin/env python3
"""PRのGreptileレビュー状態を機械的に判定するスクリプト。

Devinレビューは意図的に見ない。

Usage: python3 check_bot_review_status.py [PR_NUMBER]
  PR_NUMBER省略時は現在のブランチから自動取得。

Exit codes: 0=正常終了（完了状態はall_completeフィールドで判定）, 2=エラー
"""

import json
import re
import subprocess
import sys

GREPTILE_LOGINS = {"greptile-apps", "greptile-apps[bot]"}

GRAPHQL_QUERY = """
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          comments(first: 10) {
            nodes {
              author { login }
              body
              path
              line
              url
              createdAt
            }
          }
        }
      }
    }
  }
}
"""


def run_gh(args: list[str]) -> str:
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        print(f"gh {' '.join(args)} failed: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(2)
    return result.stdout.strip()


def get_repo_info() -> tuple[str, str]:
    data = json.loads(run_gh(["repo", "view", "--json", "owner,name"]))
    return data["owner"]["login"], data["name"]


def get_pr_number(args: list[str]) -> int:
    if args:
        return int(args[0])
    data = json.loads(run_gh(["pr", "view", "--json", "number"]))
    return data["number"]


def get_review_threads(owner: str, repo: str, pr: int) -> list[dict]:
    raw = run_gh([
        "api", "graphql",
        "-f", f"query={GRAPHQL_QUERY}",
        "-f", f"owner={owner}",
        "-f", f"repo={repo}",
        "-F", f"pr={pr}",
    ])
    data = json.loads(raw)
    return data["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]


def is_greptile_login(login: str) -> bool:
    return login in GREPTILE_LOGINS


def greptile_comments(thread: dict) -> list[dict]:
    comments = thread.get("comments", {}).get("nodes", [])
    return [
        comment for comment in comments
        if is_greptile_login(comment.get("author", {}).get("login", ""))
    ]


def unresolved_greptile_threads(threads: list[dict]) -> list[dict]:
    result = []
    for thread in threads:
        if thread.get("isResolved", True):
            continue
        if greptile_comments(thread):
            result.append(thread)
    return result


def compact_body(body: str, limit: int = 500) -> str:
    compacted = re.sub(r"\s+", " ", body).strip()
    if len(compacted) <= limit:
        return compacted
    return compacted[: limit - 1] + "…"


def summarize_thread(thread: dict) -> dict:
    comments = greptile_comments(thread)
    first = comments[0] if comments else {}
    return {
        "id": thread.get("id"),
        "path": thread.get("path") or first.get("path"),
        "line": thread.get("line") or first.get("line"),
        "url": first.get("url"),
        "body_excerpt": compact_body(first.get("body", "")),
    }


def extract_summary_p2(body: str) -> list[str]:
    """レビュー本文のSummaryセクションからP2アイテムを抽出する。"""
    items = []
    in_summary = False
    for line in body.splitlines():
        stripped = line.strip()
        if re.match(r"^#{1,3}\s+Summary", stripped, re.IGNORECASE):
            in_summary = True
            continue
        if in_summary and re.match(r"^#{1,3}\s+", stripped):
            break
        if in_summary and re.search(r"\bP2\b", stripped):
            items.append(stripped)
    return items


def confidence_from(body: str) -> str | None:
    match = re.search(r"Confidence[^0-9]*(\d)\s*/\s*5", body, re.IGNORECASE)
    if not match:
        return None
    return f"{match.group(1)}/5"


def latest_greptile_review(reviews: list[dict]) -> dict | None:
    for review in reversed(reviews):
        author = review.get("author", {}).get("login", "")
        if is_greptile_login(author):
            return review
    return None


def latest_greptile_comment(comments: list[dict]) -> dict | None:
    for comment in reversed(comments):
        author = comment.get("author", {}).get("login", "")
        if is_greptile_login(author):
            return comment
    return None


def check_greptile(pr: int, threads: list[dict]) -> dict:
    info: dict = {
        "bot": "greptile",
        "found": False,
        "approved": False,
        "confidence": None,
        "summary_p2": [],
        "unresolved_comments": 0,
        "unresolved_threads": [],
        "complete": False,
    }

    raw = run_gh(["pr", "view", str(pr), "--json", "reviews,comments"])
    pr_view = json.loads(raw)
    reviews = pr_view.get("reviews", [])
    comments = pr_view.get("comments", [])

    review_body = ""
    review = latest_greptile_review(reviews)
    if review:
        info["found"] = True
        review_body = review.get("body", "")
        info["approved"] = review.get("state", "") == "APPROVED"
        info["confidence"] = confidence_from(review_body)

    comment = latest_greptile_comment(comments)
    if comment:
        info["found"] = True
        comment_body = comment.get("body", "")
        if not info["confidence"]:
            info["confidence"] = confidence_from(comment_body)
        if not review_body:
            review_body = comment_body

    unresolved = unresolved_greptile_threads(threads)
    if unresolved:
        info["found"] = True

    info["summary_p2"] = extract_summary_p2(review_body) if review_body else []
    info["unresolved_comments"] = len(unresolved)
    info["unresolved_threads"] = [summarize_thread(thread) for thread in unresolved]
    info["complete"] = (
        (info["approved"] and info["unresolved_comments"] == 0)
        or (info["confidence"] == "5/5" and info["unresolved_comments"] == 0)
    )

    return info


def main() -> None:
    owner, repo = get_repo_info()
    pr = get_pr_number(sys.argv[1:])
    threads = get_review_threads(owner, repo, pr)
    greptile = check_greptile(pr, threads)

    result = {
        "pr_number": pr,
        "ignored_bots": ["devin"],
        "greptile": greptile,
        "all_complete": greptile["complete"],
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
