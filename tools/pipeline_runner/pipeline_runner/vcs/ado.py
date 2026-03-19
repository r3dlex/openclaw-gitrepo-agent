"""Azure DevOps API client.

All credentials come from environment variables:
- ADO_PAT: Personal Access Token
- ADO_ORG: Organization name
- ADO_PROJECT: Project name
"""

import base64
import os

import requests


def _get_config() -> tuple[str, str, str]:
    """Load ADO config from environment."""
    org = os.getenv("ADO_ORG", "")
    project = os.getenv("ADO_PROJECT", "")
    pat = os.getenv("ADO_PAT", "")
    return org, project, pat


def _get_headers(pat: str) -> dict:
    """Build auth headers for ADO API."""
    if not pat:
        return {}
    auth = base64.b64encode(f":{pat}".encode()).decode()
    return {"Authorization": f"Basic {auth}", "Content-Type": "application/json"}


def _base_url(org: str, project: str) -> str:
    return f"https://dev.azure.com/{org}/{project}/_apis"


def get_data(endpoint: str, params: dict | None = None, org: str = "", project: str = "", pat: str = "") -> dict:
    """GET request to ADO API."""
    if not org:
        org, project, pat = _get_config()
    if not pat:
        return {"error": "ADO_PAT not configured"}

    url = f"{_base_url(org, project)}/{endpoint}"
    try:
        response = requests.get(url, headers=_get_headers(pat), params=params, timeout=15)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {"error": str(e)}


def post_data(endpoint: str, data: dict | None = None, params: dict | None = None,
              org: str = "", project: str = "", pat: str = "") -> dict:
    """POST request to ADO API."""
    if not org:
        org, project, pat = _get_config()
    if not pat:
        return {"error": "ADO_PAT not configured"}

    url = f"{_base_url(org, project)}/{endpoint}"
    try:
        response = requests.post(url, headers=_get_headers(pat), params=params, json=data, timeout=15)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {"error": str(e)}


def get_pull_request(pr_id: int | str, org: str = "", project: str = "", pat: str = "") -> dict:
    """Get a pull request by ID."""
    return get_data(f"git/pullrequests/{pr_id}", {"api-version": "7.0"}, org, project, pat)


def get_pr_threads(repo_id: str, pr_id: int | str, org: str = "", project: str = "", pat: str = "") -> dict:
    """Get PR comment threads."""
    return get_data(
        f"git/repositories/{repo_id}/pullRequests/{pr_id}/threads",
        {"api-version": "7.0"}, org, project, pat,
    )


def get_pr_files(repo_id: str, pr_id: int | str, org: str = "", project: str = "", pat: str = "") -> list[dict]:
    """Get files changed in a PR."""
    iterations = get_data(
        f"git/repositories/{repo_id}/pullRequests/{pr_id}/iterations",
        {"api-version": "7.0"}, org, project, pat,
    )
    if not iterations.get("value"):
        return []

    latest = iterations["value"][0]
    changes = get_data(
        f"git/repositories/{repo_id}/pullRequests/{pr_id}/iterations/{latest['id']}/changes",
        {"api-version": "7.0"}, org, project, pat,
    )

    return [
        {"path": c.get("item", {}).get("path", ""), "type": c.get("changeType", "")}
        for c in changes.get("changeEntries", [])
    ]
