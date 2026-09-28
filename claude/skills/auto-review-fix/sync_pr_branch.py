#!/usr/bin/env python3
"""Synchronize the current PR branch with its repository default branch.

The branch is rebased onto the default branch, never merged: a merge commit on
a long-lived PR branch makes the GitHub diff and review history hard to follow.

The script performs only mechanical GitHub/Git state transitions. It never
chooses a semantic conflict resolution; the calling agent must do that.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


class CommandError(RuntimeError):
    pass


def run(
    command: list[str],
    cwd: Path,
    *,
    check: bool = True,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True, env=env)
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise CommandError(f"{' '.join(command)} failed: {detail}")
    return result


def git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(["git", *args], repo, check=check)


def git_noninteractive(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    # `rebase --continue` opens the commit editor unless one is forced.
    env = dict(os.environ, GIT_EDITOR="true")
    return run(["git", *args], repo, check=False, env=env)


def gh(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return run(["gh", *args], repo)


def repo_root() -> Path:
    result = run(["git", "rev-parse", "--show-toplevel"], Path.cwd())
    return Path(result.stdout.strip()).resolve()


def git_path(repo: Path, name: str) -> Path:
    path = Path(git(repo, "rev-parse", "--git-path", name).stdout.strip())
    return path if path.is_absolute() else repo / path


def rebase_dir(repo: Path) -> Path | None:
    path = git_path(repo, "rebase-merge")
    return path if path.is_dir() else None


def read_rebase_file(repo: Path, name: str) -> str | None:
    directory = rebase_dir(repo)
    if directory is None:
        return None
    path = directory / name
    if not path.is_file():
        return None
    lines = path.read_text(encoding="utf-8").splitlines()
    return lines[0].strip() if lines else None


def rebase_onto(repo: Path) -> str | None:
    return read_rebase_file(repo, "onto")


def rebase_branch(repo: Path) -> str | None:
    head_name = read_rebase_file(repo, "head-name")
    if head_name and head_name.startswith("refs/heads/"):
        return head_name[len("refs/heads/") :]
    return None


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
    # `rebase-merge` is this script's own resumable state and is checked
    # separately against the fetched default-branch commit.
    operation_paths = {
        "rebase-apply": "a rebase",
        "sequencer": "a sequencer operation",
        "CHERRY_PICK_HEAD": "a cherry-pick",
        "REVERT_HEAD": "a revert",
    }
    for path_name, operation in operation_paths.items():
        path = git_path(repo, path_name)
        if path.exists():
            raise CommandError(f"{operation} is already in progress at {path}; stop without changing it")


def current_branch_name(repo: Path) -> str:
    # HEAD is detached while a rebase is stopped, so the branch being rebased
    # has to come from the rebase state rather than from HEAD.
    branch = rebase_branch(repo)
    if branch:
        return branch
    return git(repo, "branch", "--show-current").stdout.strip()


def pr_context(repo: Path, requested_number: str | None) -> tuple[str, str, dict[str, object]]:
    current_branch = current_branch_name(repo)
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
    # Only the default branch is fetched. Fetching the PR branch would refresh
    # its remote-tracking ref and weaken the --force-with-lease check on push.
    git(repo, "fetch", "origin", default_branch)
    return git(repo, "rev-parse", f"refs/remotes/origin/{default_branch}").stdout.strip()


def assert_rebase_targets(repo: Path, default_sha: str) -> None:
    onto = rebase_onto(repo)
    if onto != default_sha:
        raise CommandError(
            "an in-progress rebase targets a stale or unknown default-branch commit; "
            "do not abort or overwrite it"
        )


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

    if rebase_dir(repo) is not None:
        assert_rebase_targets(repo, default_sha)
        paths = unmerged_paths(repo)
        print_state(
            "RESUME_REBASE" if paths else "REBASE_READY_TO_FINISH",
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

    rebase = git(repo, "rebase", f"origin/{default_branch}", check=False)
    if rebase.returncode != 0:
        if rebase_dir(repo) is not None and rebase_onto(repo) == default_sha:
            paths = unmerged_paths(repo)
            print_state(
                "CONFLICTS_NEED_RESOLUTION",
                branch=current_branch,
                default_branch=default_branch,
                default_sha=default_sha,
                unmerged=",".join(paths),
                pr=pr["number"],
            )
            return 2
        raise CommandError(rebase.stderr.strip() or "rebase failed without a resolvable conflict state")

    print_state(
        "REBASE_COMPLETED",
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


def push(repo: Path, current_branch: str) -> None:
    upstream = git(repo, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}", check=False)
    if upstream.returncode == 0 and upstream.stdout.strip():
        # A rebase rewrites the branch, so the push has to be forced. The lease
        # plus --force-if-includes reject the push if anyone else advanced the
        # remote branch, which a plain --force would silently discard.
        git(repo, "push", "--force-with-lease", "--force-if-includes")
    else:
        git(repo, "push", "-u", "origin", current_branch)


def finish(repo: Path, requested_number: str | None) -> int:
    current_branch, default_branch, pr = pr_context(repo, requested_number)
    validate_operation_state(repo)
    default_sha = git(repo, "rev-parse", f"refs/remotes/origin/{default_branch}").stdout.strip()

    in_rebase = rebase_dir(repo) is not None
    if in_rebase:
        assert_rebase_targets(repo, default_sha)

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

    if in_rebase:
        # A resolution that matches the new base leaves nothing to replay, and
        # `rebase --continue` refuses an empty commit; skipping is mechanical
        # because the change is already present in the default branch.
        action = "--skip" if not staged_paths(repo) else "--continue"
        result = git_noninteractive(repo, "rebase", action)
        if rebase_dir(repo) is not None:
            # A rebase replays one commit at a time, so the next commit can
            # conflict too. Hand control back and expect `finish` to be re-run.
            paths = unmerged_paths(repo)
            print_state(
                "CONFLICTS_NEED_RESOLUTION",
                branch=current_branch,
                default_branch=default_branch,
                default_sha=default_sha,
                unmerged=",".join(paths),
                pr=pr["number"],
            )
            return 2
        if result.returncode != 0:
            raise CommandError(result.stderr.strip() or f"git rebase {action} failed")

    push(repo, current_branch)
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
