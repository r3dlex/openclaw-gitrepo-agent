"""GitHub API client.

All credentials come from environment variables:
- GITHUB_TOKEN: Personal Access Token or GitHub App token
"""

import json
import os
import subprocess


def get_pr(org: str, repo: str, pr_id: str) -> dict:
    """Get PR data using gh CLI."""
    token = os.getenv("GITHUB_TOKEN", "")
    if not token:
        return {"error": "GITHUB_TOKEN not configured"}

    try:
        result = subprocess.run(
            [
                "gh", "pr", "view", str(pr_id),
                "--repo", f"{org}/{repo}",
                "--json", "title,body,files,reviews,commits,author,labels,state",
            ],
            capture_output=True, text=True, timeout=30,
            env={**os.environ, "GH_TOKEN": token},
        )
        if result.returncode != 0:
            return {"error": result.stderr.strip()}
        return json.loads(result.stdout)
    except Exception as e:
        return {"error": str(e)}


def list_prs(org: str, repo: str, state: str = "open", limit: int = 30) -> list[dict]:
    """List PRs for a repo."""
    token = os.getenv("GITHUB_TOKEN", "")
    if not token:
        return []

    try:
        result = subprocess.run(
            [
                "gh", "pr", "list",
                "--repo", f"{org}/{repo}",
                "--state", state,
                "--limit", str(limit),
                "--json", "number,title,author,createdAt,labels",
            ],
            capture_output=True, text=True, timeout=30,
            env={**os.environ, "GH_TOKEN": token},
        )
        if result.returncode != 0:
            return []
        return json.loads(result.stdout)
    except Exception:
        return []
