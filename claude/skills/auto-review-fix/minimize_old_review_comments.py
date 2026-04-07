#!/usr/bin/env python3
"""古い @greptileai review コメントをHide（Minimize）するスクリプト。

最新の1つを残して、それ以外を OUTDATED としてMinimizeする。

Usage: python3 minimize_old_review_comments.py [PR_NUMBER]
  PR_NUMBER省略時は現在のブランチから自動取得。

Exit codes: 0=Minimize実行, 1=対象なし, 2=エラー
"""

import json
import subprocess
import sys

COMMENTS_QUERY = """
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      comments(first: 100) {
        nodes {
          id
          body
          createdAt
          isMinimized
          author { login }
        }
      }
    }
  }
}
"""

MINIMIZE_MUTATION = """
mutation($id: ID!) {
  minimizeComment(input: {subjectId: $id, classifier: OUTDATED}) {
    minimizedComment {
      isMinimized
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


def get_current_user() -> str:
    return run_gh(["api", "user", "--jq", ".login"])


def get_pr_comments(owner: str, repo: str, pr: int) -> list[dict]:
    raw = run_gh([
        "api", "graphql",
        "-f", f"query={COMMENTS_QUERY}",
        "-f", f"owner={owner}",
        "-f", f"repo={repo}",
        "-F", f"pr={pr}",
    ])
    data = json.loads(raw)
    return data["data"]["repository"]["pullRequest"]["comments"]["nodes"]


def minimize_comment(comment_id: str) -> bool:
    raw = run_gh([
        "api", "graphql",
        "-f", f"query={MINIMIZE_MUTATION}",
        "-f", f"id={comment_id}",
    ])
    data = json.loads(raw)
    return data["data"]["minimizeComment"]["minimizedComment"]["isMinimized"]


def main() -> None:
    owner, repo = get_repo_info()
    pr = get_pr_number(sys.argv[1:])
    current_user = get_current_user()

    comments = get_pr_comments(owner, repo, pr)

    # 自分が投稿した @greptileai review コメントをフィルタ
    review_comments = [
        c for c in comments
        if c.get("author", {}).get("login") == current_user
        and "@greptileai review" in c.get("body", "")
        and not c.get("isMinimized", False)
    ]

    if len(review_comments) < 2:
        result = {
            "pr_number": pr,
            "total_found": len(review_comments),
            "minimized": 0,
            "message": "対象のコメントが2件未満のためスキップ",
        }
        print(json.dumps(result, indent=2, ensure_ascii=False))
        sys.exit(1)

    # createdAtでソートして最新を残す
    review_comments.sort(key=lambda c: c["createdAt"])
    to_minimize = review_comments[:-1]
    kept = review_comments[-1]

    minimized_count = 0
    for comment in to_minimize:
        if minimize_comment(comment["id"]):
            minimized_count += 1

    result = {
        "pr_number": pr,
        "total_found": len(review_comments),
        "minimized": minimized_count,
        "kept": {
            "id": kept["id"],
            "createdAt": kept["createdAt"],
        },
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    main()
