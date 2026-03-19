"""PR review step — evaluates pull requests using the 5-category scoring system."""

import json
import os
import subprocess

from dotenv import load_dotenv

from pipeline_runner.steps import PipelineStep


class PrReviewStep(PipelineStep):
    """
    Evaluates PRs from input/TASK.md using VCS APIs.

    Scoring categories (see spec/SCORING.md):
    - Security: 25%
    - Design: 25%
    - Practices: 20%
    - Style: 15%
    - Documentation: 15%
    """

    WEIGHTS = {
        "security": 0.25,
        "design": 0.25,
        "practices": 0.20,
        "style": 0.15,
        "documentation": 0.15,
    }

    @property
    def name(self) -> str:
        return "pr-review"

    def run(self) -> dict:
        load_dotenv(self.repo_path / ".env")
        findings = []

        task_path = self.repo_path / "input" / "TASK.md"
        if not task_path.exists():
            return self._result("skipped", [{"severity": "info", "message": "No TASK.md found", "file": None}])

        content = task_path.read_text()
        import re

        # Only scan the Queue section (after "## Queue"), skip examples in code blocks
        queue_match = re.search(r"## Queue\s*\n", content)
        queue_section = content[queue_match.end():] if queue_match else ""
        # Remove code blocks to avoid matching examples
        queue_clean = re.sub(r"```.*?```", "", queue_section, flags=re.DOTALL)
        tasks = re.findall(r"- \[ \] (\w+):([^/]+)/([^#]+)#(\d+)", queue_clean)

        if not tasks:
            return self._result("passed", [{"severity": "info", "message": "No PRs in queue", "file": None}])

        for vcs, org, project, pr_id in tasks:
            result = self._evaluate_pr(vcs, org, project, pr_id)
            findings.extend(result)

        status = "failed" if any(f["severity"] == "error" for f in findings) else "passed"
        return self._result(status, findings)

    def _evaluate_pr(self, vcs: str, org: str, project: str, pr_id: str) -> list:
        findings = []
        pr_ref = f"{vcs}:{org}/{project}#{pr_id}"

        if vcs == "github":
            findings.extend(self._evaluate_github_pr(org, project, pr_id))
        elif vcs == "ado":
            findings.extend(self._evaluate_ado_pr(org, project, pr_id))
        else:
            findings.append({
                "severity": "info",
                "message": f"VCS '{vcs}' not yet supported for PR review: {pr_ref}",
                "file": None,
            })

        return findings

    def _evaluate_github_pr(self, org: str, repo: str, pr_id: str) -> list:
        findings = []
        token = os.getenv("GITHUB_TOKEN", "")
        if not token:
            findings.append({
                "severity": "warning",
                "message": "GITHUB_TOKEN not set, skipping GitHub PR review",
                "file": None,
            })
            return findings

        try:
            result = subprocess.run(
                ["gh", "pr", "view", pr_id, "--repo", f"{org}/{repo}", "--json",
                 "title,body,files,reviews,commits,author,labels"],
                capture_output=True, text=True, timeout=30,
            )
            if result.returncode != 0:
                err = result.stderr.strip()
                findings.append({
                    "severity": "error",
                    "message": f"Failed to fetch GitHub PR {org}/{repo}#{pr_id}: {err}",
                    "file": None,
                })
                return findings

            pr_data = json.loads(result.stdout)
            score = self._score_pr(pr_data)
            verdict = self._verdict(score)

            severity = "info" if score >= 70 else "warning" if score >= 50 else "error"
            findings.append({
                "severity": severity,
                "message": (
                    f"PR {org}/{repo}#{pr_id}: score={score:.1f}, "
                    f"verdict={verdict}, "
                    f"author={pr_data.get('author', {}).get('login', 'unknown')}"
                ),
                "file": None,
            })

        except Exception as e:
            findings.append({"severity": "error", "message": f"Error evaluating GitHub PR: {e}", "file": None})

        return findings

    def _evaluate_ado_pr(self, org: str, project: str, pr_id: str) -> list:
        findings = []
        pat = os.getenv("ADO_PAT", "")
        if not pat:
            findings.append({
                "severity": "warning",
                "message": "ADO_PAT not set, skipping ADO PR review",
                "file": None,
            })
            return findings

        import base64

        import requests

        try:
            auth = base64.b64encode(f":{pat}".encode()).decode()
            headers = {"Authorization": f"Basic {auth}", "Content-Type": "application/json"}
            base_url = f"https://dev.azure.com/{org}/{project}/_apis"

            resp = requests.get(
                f"{base_url}/git/pullrequests/{pr_id}",
                headers=headers, params={"api-version": "7.0"}, timeout=15,
            )
            resp.raise_for_status()
            pr_data = resp.json()

            score = self._score_ado_pr(pr_data)
            verdict = self._verdict(score)

            severity = "info" if score >= 70 else "warning" if score >= 50 else "error"
            author = pr_data.get("createdBy", {}).get("displayName", "unknown")
            findings.append({
                "severity": severity,
                "message": f"PR {org}/{project}#{pr_id}: score={score:.1f}, verdict={verdict}, author={author}",
                "file": None,
            })

        except Exception as e:
            findings.append({"severity": "error", "message": f"Error evaluating ADO PR: {e}", "file": None})

        return findings

    def _score_pr(self, pr_data: dict) -> float:
        """Score a GitHub PR."""
        scores = {"security": 80, "design": 80, "practices": 80, "style": 80, "documentation": 80}

        # Deductions
        if not pr_data.get("body"):
            scores["documentation"] -= 30

        files = pr_data.get("files", [])
        if len(files) > 20:
            scores["design"] -= 20

        if len(files) == 0:
            scores["practices"] -= 30

        return sum(scores[k] * self.WEIGHTS[k] for k in self.WEIGHTS)

    def _score_ado_pr(self, pr_data: dict) -> float:
        """Score an ADO PR."""
        scores = {"security": 80, "design": 80, "practices": 80, "style": 80, "documentation": 80}

        if not pr_data.get("description"):
            scores["documentation"] -= 30

        reviewers = pr_data.get("reviewers", [])
        active_rejects = sum(1 for r in reviewers if r.get("vote", 0) < 0)
        if active_rejects > 0:
            scores["practices"] -= 20

        return sum(scores[k] * self.WEIGHTS[k] for k in self.WEIGHTS)

    @staticmethod
    def _verdict(score: float) -> str:
        if score >= 90:
            return "approve"
        if score >= 70:
            return "approve_with_comments"
        if score >= 50:
            return "request_changes"
        return "reject"
