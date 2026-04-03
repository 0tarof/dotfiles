#!/usr/bin/env python3
"""PRのBotレビュー（Greptile、Devin）の完了状態を機械的に判定するスクリプト。

Usage: python3 check_bot_review_status.py [PR_NUMBER]
  PR_NUMBER省略時は現在のブランチから自動取得。

Exit codes: 0=全Bot完了, 1=未完了, 2=エラー
"""

import json
import re
import subprocess
import sys

GRAPHQL_QUERY = """
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 1) {
            nodes {
              author { login }
              body
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


def unresolved_threads_by(threads: list[dict], login: str) -> list[dict]:
    result = []
    for t in threads:
        comments = t.get("comments", {}).get("nodes", [])
        if not comments:
            continue
        author = comments[0].get("author", {}).get("login", "")
        if author == login and not t.get("isResolved", True):
            result.append(t)
    return result


def check_greptile(owner: str, repo: str, pr: int, threads: list[dict]) -> dict:
    bot = "greptile-apps[bot]"
    info: dict = {
        "bot": "greptile",
        "found": False,
        "confidence": None,
        "unresolved_comments": 0,
        "complete": False,
    }

    # reviewsからConfidenceを取得
    raw = run_gh(["pr", "view", str(pr), "--json", "reviews"])
    reviews = json.loads(raw).get("reviews", [])

    # 最新のgreptileレビューを探す
    for review in reversed(reviews):
        author = review.get("author", {}).get("login", "")
        if author == bot:
            info["found"] = True
            body = review.get("body", "")
            m = re.search(r"Confidence\s*(\d+)/5", body)
            if m:
                info["confidence"] = f"{m.group(1)}/5"
            break

    # commentsにもConfidenceがある場合がある
    if not info["found"]:
        raw = run_gh(["pr", "view", str(pr), "--json", "comments"])
        comments = json.loads(raw).get("comments", [])
        for comment in reversed(comments):
            author = comment.get("author", {}).get("login", "")
            if author == bot:
                info["found"] = True
                body = comment.get("body", "")
                m = re.search(r"Confidence\s*(\d+)/5", body)
                if m:
                    info["confidence"] = f"{m.group(1)}/5"
                break

    # 未解決インラインコメント
    unresolved = unresolved_threads_by(threads, bot)
    info["unresolved_comments"] = len(unresolved)

    # 完了判定: Confidence 5/5 かつ 未解決コメント0件
    info["complete"] = info["confidence"] == "5/5" and info["unresolved_comments"] == 0

    return info


def check_devin(owner: str, repo: str, pr: int, threads: list[dict]) -> dict:
    bot = "devin-ai-integration[bot]"
    info: dict = {
        "bot": "devin",
        "found": False,
        "no_issues_comment": False,
        "checks_pass": None,
        "unresolved_comments": 0,
        "complete": False,
    }

    # "No Issues Found" コメントを確認
    raw = run_gh(["pr", "view", str(pr), "--json", "comments"])
    comments = json.loads(raw).get("comments", [])
    for comment in comments:
        author = comment.get("author", {}).get("login", "")
        if author == bot:
            info["found"] = True
            if "Devin Review: No Issues Found" in comment.get("body", ""):
                info["no_issues_comment"] = True

    # reviewsも確認
    raw = run_gh(["pr", "view", str(pr), "--json", "reviews"])
    reviews = json.loads(raw).get("reviews", [])
    for review in reviews:
        author = review.get("author", {}).get("login", "")
        if author == bot:
            info["found"] = True

    # checksでDevin Reviewの状態を確認
    checks_output = run_gh(["pr", "checks", str(pr)])
    for line in checks_output.splitlines():
        if "Devin Review" in line or "devin" in line.lower():
            info["checks_pass"] = "pass" in line

    # 未解決インラインコメント
    unresolved = unresolved_threads_by(threads, bot)
    info["unresolved_comments"] = len(unresolved)

    # 完了判定
    if info["no_issues_comment"]:
        info["complete"] = True
    elif info["checks_pass"] and info["unresolved_comments"] == 0:
        info["complete"] = True

    return info


def main() -> None:
    owner, repo = get_repo_info()
    pr = get_pr_number(sys.argv[1:])
    threads = get_review_threads(owner, repo, pr)

    greptile = check_greptile(owner, repo, pr, threads)
    devin = check_devin(owner, repo, pr, threads)

    result = {
        "pr_number": pr,
        "greptile": greptile,
        "devin": devin,
        "all_complete": greptile["complete"] and devin["complete"],
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))
    sys.exit(0 if result["all_complete"] else 1)


if __name__ == "__main__":
    main()
