"""Security pipeline step — scans for secrets and sensitive data."""

import re

from pipeline_runner.steps import PipelineStep

# Patterns that indicate leaked secrets
SECRET_PATTERNS = [
    (r"(?i)(password|passwd|pwd)\s*[=:]\s*['\"][^'\"]{8,}", "Possible hardcoded password"),
    (r"(?i)(api[_-]?key|apikey)\s*[=:]\s*['\"][^'\"]{8,}", "Possible hardcoded API key"),
    (r"(?i)(secret|token)\s*[=:]\s*['\"][^'\"]{8,}", "Possible hardcoded secret/token"),
    (r"(?i)Bearer\s+[A-Za-z0-9\-._~+/]+=*", "Possible hardcoded Bearer token"),
    (r"ghp_[A-Za-z0-9]{36}", "GitHub Personal Access Token"),
    (r"(?i)-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----", "Private key detected"),
]

# Files to skip
SKIP_EXTENSIONS = {".pyc", ".beam", ".so", ".o", ".exe", ".png", ".jpg", ".gif", ".ico"}
SKIP_DIRS = {".git", "__pycache__", "_build", "deps", "node_modules", ".venv", "venv", ".ruff_cache", ".pytest_cache"}
# Files that contain regex patterns for secret detection (would trigger false positives on themselves)
SKIP_FILES = {"security.py", ".pipeline-result.json", ".env.example"}


class SecurityStep(PipelineStep):
    @property
    def name(self) -> str:
        return "security"

    def run(self) -> dict:
        findings = []

        # Check .gitignore exists and contains .env
        gitignore = self.repo_path / ".gitignore"
        if not gitignore.exists():
            findings.append({"severity": "error", "message": "No .gitignore found", "file": None})
        else:
            content = gitignore.read_text()
            if ".env" not in content:
                findings.append({"severity": "error", "message": ".gitignore does not exclude .env", "file": str(gitignore)})

        # Check .env.example exists
        env_example = self.repo_path / ".env.example"
        if not env_example.exists():
            findings.append({"severity": "warning", "message": "No .env.example found", "file": None})

        # Scan files for secrets
        for path in self._walk_files():
            try:
                content = path.read_text(errors="ignore")
            except Exception:
                continue

            rel_path = str(path.relative_to(self.repo_path))
            for pattern, description in SECRET_PATTERNS:
                if re.search(pattern, content):
                    findings.append({
                        "severity": "error",
                        "message": f"{description} in {rel_path}",
                        "file": rel_path,
                    })

        status = "failed" if any(f["severity"] == "error" for f in findings) else "passed"
        return self._result(status, findings)

    def _walk_files(self):
        for path in self.repo_path.rglob("*"):
            if path.is_dir():
                continue
            if any(skip in path.parts for skip in SKIP_DIRS):
                continue
            if path.suffix in SKIP_EXTENSIONS:
                continue
            if path.name in SKIP_FILES:
                continue
            yield path
