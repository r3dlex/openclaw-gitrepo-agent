"""Architecture pipeline step — validates structural requirements."""


from pipeline_runner.steps import PipelineStep

REQUIRED_FILES = [
    "CLAUDE.md",
    "AGENTS.md",
    "SOUL.md",
    "IDENTITY.md",
    ".env.example",
    ".gitignore",
    "mix.exs",
    "docker-compose.yml",
    "Dockerfile",
]

REQUIRED_DIRS = [
    "spec",
    "lib/gitrepo_agent",
    "tools/pipeline_runner",
    ".archgate/adrs",
    "config",
    "input",
]


class ArchitectureStep(PipelineStep):
    @property
    def name(self) -> str:
        return "architecture"

    def run(self) -> dict:
        findings = []

        # Check required files
        for filename in REQUIRED_FILES:
            if not (self.repo_path / filename).exists():
                findings.append({
                    "severity": "error",
                    "message": f"Required file missing: {filename}",
                    "file": filename,
                })

        # Check required directories
        for dirname in REQUIRED_DIRS:
            if not (self.repo_path / dirname).is_dir():
                findings.append({
                    "severity": "error",
                    "message": f"Required directory missing: {dirname}",
                    "file": dirname,
                })

        # Check spec files
        spec_dir = self.repo_path / "spec"
        if spec_dir.is_dir():
            expected_specs = ["ARCHITECTURE.md", "PIPELINES.md", "WORKFLOW.md", "SCORING.md",
                             "TROUBLESHOOTING.md", "LEARNINGS.md", "COMMUNICATION.md", "SAFETY.md"]
            for spec_file in expected_specs:
                if not (spec_dir / spec_file).exists():
                    findings.append({
                        "severity": "warning",
                        "message": f"Missing spec file: spec/{spec_file}",
                        "file": f"spec/{spec_file}",
                    })

        status = "failed" if any(f["severity"] == "error" for f in findings) else "passed"
        return self._result(status, findings)
