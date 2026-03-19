"""ADR validation step — ensures Architecture Decision Records follow conventions."""

import re

from pipeline_runner.steps import PipelineStep

ADR_PATTERN = re.compile(r"^ARCH-(\d{3})-[\w-]+\.md$")
REQUIRED_SECTIONS = ["## Context", "## Decision", "## Consequences"]


class AdrCheckStep(PipelineStep):
    @property
    def name(self) -> str:
        return "adr-check"

    def run(self) -> dict:
        findings = []
        adr_dir = self.repo_path / ".archgate" / "adrs"

        if not adr_dir.is_dir():
            findings.append({
                "severity": "error",
                "message": "ADR directory not found: .archgate/adrs/",
                "file": None,
            })
            return self._result("failed", findings)

        adr_files = sorted(adr_dir.glob("ARCH-*.md"))
        if not adr_files:
            findings.append({
                "severity": "warning",
                "message": "No ADR files found",
                "file": None,
            })
            return self._result("passed", findings)

        seen_numbers = set()
        for adr_path in adr_files:
            rel_path = str(adr_path.relative_to(self.repo_path))
            match = ADR_PATTERN.match(adr_path.name)

            if not match:
                findings.append({
                    "severity": "error",
                    "message": f"ADR filename does not follow ARCH-NNN-title.md convention: {adr_path.name}",
                    "file": rel_path,
                })
                continue

            number = int(match.group(1))
            if number in seen_numbers:
                findings.append({
                    "severity": "error",
                    "message": f"Duplicate ADR number: ARCH-{number:03d}",
                    "file": rel_path,
                })
            seen_numbers.add(number)

            # Check required sections
            content = adr_path.read_text()
            for section in REQUIRED_SECTIONS:
                if section not in content:
                    findings.append({
                        "severity": "warning",
                        "message": f"Missing section '{section}' in {adr_path.name}",
                        "file": rel_path,
                    })

            # Check status field
            if "**Status:**" not in content:
                findings.append({
                    "severity": "warning",
                    "message": f"Missing Status field in {adr_path.name}",
                    "file": rel_path,
                })

        status = "failed" if any(f["severity"] == "error" for f in findings) else "passed"
        return self._result(status, findings)
