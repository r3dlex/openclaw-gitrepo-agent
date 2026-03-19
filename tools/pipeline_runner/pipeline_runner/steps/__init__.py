"""Pipeline steps base class."""

from abc import ABC, abstractmethod
from pathlib import Path


class PipelineStep(ABC):
    """Base class for pipeline steps."""

    def __init__(self, repo_path: Path):
        self.repo_path = repo_path

    @property
    @abstractmethod
    def name(self) -> str:
        """Step name."""

    @abstractmethod
    def run(self) -> dict:
        """
        Run the step and return a result dict.

        Returns:
            {
                "name": str,
                "status": "passed" | "failed" | "skipped",
                "error_count": int,
                "findings": [{"severity": "error"|"warning"|"info", "message": str, "file": str|None}]
            }
        """

    def _result(self, status: str, findings: list | None = None) -> dict:
        findings = findings or []
        error_count = sum(1 for f in findings if f["severity"] == "error")
        return {
            "name": self.name,
            "status": status,
            "error_count": error_count,
            "findings": findings,
        }
