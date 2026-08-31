#!/usr/bin/env python3
"""Synchronize the current PR branch with its repository default branch.

The script performs only mechanical GitHub/Git state transitions. It never
chooses a semantic conflict resolution; the calling agent must do that.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


class CommandError(RuntimeError):
    pass


def run(command: list[str], cwd: Path, *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise CommandError(f"{' '.join(command)} failed: {detail}")
    return result


def git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(["git", *args], repo, check=check)


def gh(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return run(["gh", *args], repo)


def repo_root() -> Path:
    result = run(["git", "rev-parse", "--show-toplevel"], Path.cwd())
    return Path(result.stdout.strip()).resolve()


def git_path(repo: Path, name: str) -> Path:
    path = Path(git(repo, "rev-parse", "--git-path", name).stdout.strip())
    return path if path.is_absolute() else repo / path


def read_merge_head(repo: Path) -> str | None:
    path = git_path(repo, "MERGE_HEAD")
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8").splitlines()[0].strip()


def unmerged_paths(repo: Path) -> list[str]:
    result = git(repo, "ls-files", "-u", "-z")
    paths: set[str] = set()
    for entry in result.stdout.split("\0"):
        if not entry:
            continue
        _, path = entry.split("\t", 1)
        paths.add(path)
    return sorted(paths)


def staged_paths(repo: Path) -> list[str]:
    result = git(repo, "diff", "--cached", "--name-only", "-z")
    return sorted({path for path in result.stdout.split("\0") if path})


def untracked_paths(repo: Path) -> list[str]:
    result = git(repo, "ls-files", "--others", "--exclude-standard", "-z")
    return sorted({path for path in result.stdout.split("\0") if path})


def validate_operation_state(repo: Path) -> None:
    operation_paths = {
        "rebase-merge": "a rebase",
        "rebase-apply": "a rebase",
        "sequencer": "a sequencer operation",
        "CHERRY_PICK_HEAD": "a cherry-pick",
        "REVERT_HEAD": "a revert",
    }
    for path_name, operation in operation_paths.items():
        path = git_path(repo, path_name)
        if path.exists():
            raise CommandError(f"{operation} is already in progress at {path}; stop without changing it")


def pr_context(repo: Path, requested_number: str | None) -> tuple[str, str, dict[str, object]]:
    current_branch = git(repo, "branch", "--show-current").stdout.strip()
    if not current_branch:
        raise CommandError("the current checkout is detached; stop before changing it")

    repo_data = json.loads(gh(repo, "repo", "view", "--json", "defaultBranchRef").stdout)
    default_branch = str(repo_data["defaultBranchRef"]["name"])
    if current_branch == default_branch:
        raise CommandError(f"current branch is the default branch ({default_branch}); refusing to mutate it")

    pr_args = ["pr", "view"]
    if requested_number:
        pr_args.append(requested_number)
    pr_args.extend(["--json", "number,state,headRefName,baseRefName"])
    pr = json.loads(gh(repo, *pr_args).stdout)
    if pr.get("state") != "OPEN":
        raise CommandError(f"PR is not open: state={pr.get('state')}")
    if pr.get("headRefName") != current_branch:
        raise CommandError(
            f"PR head {pr.get('headRefName')!r} does not match current branch {current_branch!r}"
        )
    if pr.get("baseRefName") != default_branch:
        raise CommandError(
            f"PR base {pr.get('baseRefName')!r} is not the repository default branch {default_branch!r}"
        )
    return current_branch, default_branch, pr


def fetch_default(repo: Path, default_branch: str) -> str:
    git(repo, "fetch", "origin", default_branch)
    return git(repo, "rev-parse", f"refs/remotes/origin/{default_branch}").stdout.strip()


def status(repo: Path) -> str:
    return git(repo, "status", "--porcelain=v1").stdout


def print_state(state: str, **values: object) -> None:
    print(f"SYNC_STATE={state}")
    for key, value in values.items():
        print(f"{key}={value}")


def prepare(repo: Path, requested_number: str | None) -> int:
    current_branch, default_branch, pr = pr_context(repo, requested_number)
    validate_operation_state(repo)
    default_sha = fetch_default(repo, default_branch)
    merge_head = read_merge_head(repo)

    if merge_head:
        if merge_head != default_sha:
            raise CommandError(
                "an in-progress merge targets a stale or unknown default-branch commit; "
                "do not abort or overwrite it"
            )
        paths = unmerged_paths(repo)
        print_state(
            "RESUME_MERGE" if paths else "MERGE_READY_TO_FINISH",
            branch=current_branch,
            default_branch=default_branch,
            default_sha=default_sha,
            unmerged=",".join(paths),
            pr=pr["number"],
        )
        return 2 if paths else 0

    if status(repo):
        raise CommandError("worktree is not clean; refusing to stash, reset, clean, or overwrite it")

    ancestor = git(repo, "merge-base", "--is-ancestor", f"origin/{default_branch}", "HEAD", check=False)
    if ancestor.returncode == 0:
        print_state(
            "SYNC_NOT_NEEDED",
            branch=current_branch,
            default_branch=default_branch,
            default_sha=default_sha,
            pr=pr["number"],
        )
        return 0
    if ancestor.returncode != 1:
        raise CommandError(ancestor.stderr.strip() or "could not compare the branch with the default branch")

    merge = git(repo, "merge", "--no-edit", f"origin/{default_branch}", check=False)
    if merge.returncode != 0:
        merge_head = read_merge_head(repo)
        paths = unmerged_paths(repo)
        if merge_head == default_sha and paths:
            print_state(
                "CONFLICTS_NEED_RESOLUTION",
                branch=current_branch,
                default_branch=default_branch,
                default_sha=default_sha,
                unmerged=",".join(paths),
                pr=pr["number"],
            )
            return 2
        raise CommandError(merge.stderr.strip() or "merge failed without a resolvable conflict state")

    print_state(
        "MERGE_COMPLETED",
        branch=current_branch,
        default_branch=default_branch,
        default_sha=default_sha,
        pr=pr["number"],
    )
    return 0


CONFLICT_MARKER = re.compile(r"^(<<<<<<<|=======|>>>>>>>)")


def check_conflict_markers(repo: Path, paths: list[str]) -> None:
    problems: list[str] = []
    for relative_path in paths:
        path = repo / relative_path
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b"\0" in data:
            continue
        text = data.decode("utf-8", errors="replace")
        for line_number, line in enumerate(text.splitlines(), 1):
            if CONFLICT_MARKER.match(line):
                problems.append(f"{relative_path}:{line_number}")
    if problems:
        raise CommandError("conflict markers remain at " + ", ".join(problems))


def finish(repo: Path, requested_number: str | None) -> int:
    current_branch, default_branch, pr = pr_context(repo, requested_number)
    validate_operation_state(repo)
    default_sha = git(repo, "rev-parse", f"refs/remotes/origin/{default_branch}").stdout.strip()
    merge_head = read_merge_head(repo)
    paths = unmerged_paths(repo)
    if paths:
        check_conflict_markers(repo, paths)
        git(repo, "add", "--", *paths)
    if unmerged_paths(repo):
        raise CommandError("unmerged paths remain after staging; refusing to commit")
    check_conflict_markers(repo, staged_paths(repo))
    if git(repo, "diff", "--name-only").stdout.strip():
        raise CommandError("unstaged changes remain; refusing to commit or push")
    untracked = untracked_paths(repo)
    if untracked:
        raise CommandError("untracked files remain; refusing to commit or push: " + ", ".join(untracked))
    git(repo, "diff", "--cached", "--check")

    if merge_head:
        if merge_head != default_sha:
            raise CommandError("MERGE_HEAD no longer matches the fetched default branch; refusing to commit")
        git(repo, "commit", "--no-edit")

    upstream = git(repo, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}", check=False)
    if upstream.returncode == 0 and upstream.stdout.strip():
        git(repo, "push")
    else:
        git(repo, "push", "-u", "origin", current_branch)
    print_state(
        "SYNC_FINISHED",
        branch=current_branch,
        default_branch=default_branch,
        default_sha=default_sha,
        pr=pr["number"],
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "finish"))
    parser.add_argument("--pr", help="PR number; defaults to the PR for the current branch")
    args = parser.parse_args()
    try:
        repo = repo_root()
        if args.command == "prepare":
            return prepare(repo, args.pr)
        return finish(repo, args.pr)
    except (CommandError, json.JSONDecodeError, KeyError, IndexError) as error:
        print(f"sync_pr_branch: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
