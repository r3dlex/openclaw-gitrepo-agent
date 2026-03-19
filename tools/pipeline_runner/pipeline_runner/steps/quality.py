"""Quality pipeline step — code linting and formatting checks."""

import subprocess

from pipeline_runner.steps import PipelineStep


class QualityStep(PipelineStep):
    @property
    def name(self) -> str:
        return "quality"

    def run(self) -> dict:
        findings = []

        # Python linting with ruff
        findings.extend(self._check_ruff())

        # Elixir format check
        findings.extend(self._check_elixir_format())

        status = "failed" if any(f["severity"] == "error" for f in findings) else "passed"
        return self._result(status, findings)

    def _check_ruff(self) -> list:
        findings = []
        python_dir = self.repo_path / "tools" / "pipeline_runner"
        if not python_dir.exists():
            return findings

        try:
            result = subprocess.run(
                ["ruff", "check", str(python_dir), "--output-format=json"],
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode != 0 and result.stdout:
                import json
                issues = json.loads(result.stdout)
                for issue in issues[:20]:  # Cap at 20
                    code = issue.get('code', '?')
                    msg = issue.get('message', '')
                    fname = issue.get('filename', '')
                    row = issue.get('location', {}).get('row', '?')
                    findings.append({
                        "severity": "warning",
                        "message": f"ruff: {code} {msg} ({fname}:{row})",
                        "file": fname,
                    })
        except FileNotFoundError:
            findings.append({"severity": "info", "message": "ruff not installed, skipping Python lint", "file": None})
        except Exception as e:
            findings.append({"severity": "info", "message": f"ruff check failed: {e}", "file": None})

        return findings

    def _check_elixir_format(self) -> list:
        findings = []
        mix_file = self.repo_path / "mix.exs"
        if not mix_file.exists():
            return findings

        try:
            result = subprocess.run(
                ["mix", "format", "--check-formatted"],
                capture_output=True, text=True, timeout=60,
                cwd=str(self.repo_path),
            )
            if result.returncode != 0:
                findings.append({
                    "severity": "warning",
                    "message": "Elixir files not formatted (run `mix format`)",
                    "file": None,
                })
        except FileNotFoundError:
            findings.append({
                "severity": "info",
                "message": "mix not installed, skipping Elixir format check",
                "file": None,
            })
        except Exception as e:
            findings.append({"severity": "info", "message": f"Elixir format check failed: {e}", "file": None})

        return findings
