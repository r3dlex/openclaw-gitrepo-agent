"""CLI entry point for pipeline_runner."""

import json
import sys
import time
from pathlib import Path

from pipeline_runner.steps.adr_check import AdrCheckStep
from pipeline_runner.steps.architecture import ArchitectureStep
from pipeline_runner.steps.pr_review import PrReviewStep
from pipeline_runner.steps.quality import QualityStep
from pipeline_runner.steps.security import SecurityStep

PIPELINES = {
    "security": [SecurityStep],
    "architecture": [ArchitectureStep],
    "quality": [QualityStep],
    "adr-check": [AdrCheckStep],
    "pr-review": [PrReviewStep],
    "full": [SecurityStep, ArchitectureStep, QualityStep, AdrCheckStep],
    "ci": [SecurityStep, ArchitectureStep, QualityStep, AdrCheckStep],
}


def run_pipeline(name: str, repo_path: str | None = None) -> dict:
    """Run a named pipeline and return structured results."""
    if name not in PIPELINES:
        print(f"Unknown pipeline: {name}")
        print(f"Available: {', '.join(PIPELINES.keys())}")
        sys.exit(1)

    steps = PIPELINES[name]
    target = Path(repo_path).resolve() if repo_path else Path.cwd().parent.parent.resolve()

    results = []
    overall_passed = True

    print(f"=== Pipeline: {name} ===")
    print(f"Target: {target}")
    print()

    for step_class in steps:
        step = step_class(target)
        start = time.time()
        result = step.run()
        duration_ms = int((time.time() - start) * 1000)
        result["duration_ms"] = duration_ms

        status_map = {"passed": "\u2705", "failed": "\u274c"}
        status_icon = status_map.get(result["status"], "\u23ed\ufe0f")
        print(f"  {status_icon} {result['name']}: {result['status']} ({duration_ms}ms)")

        sev_icons = {"error": "\U0001f534", "warning": "\U0001f7e1", "info": "\U0001f535"}
        for finding in result.get("findings", []):
            severity_icon = sev_icons.get(finding["severity"], "\u26aa")
            print(f"     {severity_icon} {finding['message']}")

        if result["status"] == "failed":
            overall_passed = False

        results.append(result)

    print()
    print(f"{'\u2705 PASSED' if overall_passed else '\u274c FAILED'}")

    return {
        "pipeline": name,
        "passed": overall_passed,
        "steps": results,
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: python -m pipeline_runner <pipeline> [repo_path]")
        print(f"Pipelines: {', '.join(PIPELINES.keys())}")
        sys.exit(1)

    pipeline_name = sys.argv[1]
    repo_path = sys.argv[2] if len(sys.argv) > 2 else None

    result = run_pipeline(pipeline_name, repo_path)

    # Write JSON result
    output_path = Path.cwd() / ".pipeline-result.json"
    output_path.write_text(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
