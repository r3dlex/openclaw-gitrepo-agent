# Pipeline Definitions

All pipelines run via `docker compose run --rm pipeline-runner` and return structured results. Each pipeline step produces a result object with `status`, `error_count`, and `findings`.

## Result Structure

Every pipeline step returns:

```json
{
  "pipeline": "<name>",
  "status": "passed | failed | skipped",
  "error_count": 0,
  "findings": [
    {
      "severity": "critical | high | medium | low | info",
      "file": "path/to/file",
      "line": 42,
      "message": "Description of the finding",
      "rule": "rule-identifier"
    }
  ]
}
```

## Pipeline Definitions

### `security`

Scans for secrets and security misconfigurations.

- `.env` file presence check (should not be committed)
- Token pattern detection (API keys, passwords, connection strings)
- `.gitignore` validation (ensures sensitive patterns are excluded)
- Hardcoded credential detection in source files

Severity: findings here are typically `critical` or `high`.

### `architecture`

Validates structural compliance with project architecture rules.

- ADR existence check in `.archgate/adrs/`
- Archgate compliance validation
- Module structure validation (correct boundaries, no circular dependencies)
- Import/dependency direction enforcement

### `quality`

Code quality and formatting checks.

- Python linting via `ruff`
- Elixir formatting via `mix format --check-formatted`
- Complexity metrics (function length, nesting depth)
- Dead code detection

### `adr-check`

Validates all Architecture Decision Records follow the required format.

- File naming follows `ARCH-NNN` pattern (e.g., `ARCH-001_decision_title.md`)
- Required sections present: Status, Context, Decision, Consequences
- No orphaned ADRs (referenced but missing) or unreferenced ADRs
- Status values are valid: `proposed`, `accepted`, `deprecated`, `superseded`

### `pr-review`

Automated PR scoring using the 5-category weighted system.

- Fetches PR diff and metadata from VCS
- Runs security, architecture, and quality checks on changed files only
- Produces a weighted score across all 5 categories
- Generates a verdict: approve, approve_with_comments, request_changes, or reject

See [SCORING.md](SCORING.md) for the full scoring methodology.

### `full`

Runs all pipelines in sequence: `security` -> `architecture` -> `quality` -> `adr-check` -> `pr-review`.

Results are aggregated into a single report. A failure in `security` does not prevent subsequent pipelines from running.

### `ci`

GitHub Actions pipeline combining `security` + `architecture` + `quality` + tests.

This is the subset suitable for CI/CD environments where PR review scoring is not needed. Exits with non-zero status if any pipeline produces `critical` or `high` findings.

## Execution

Run a specific pipeline:

```bash
docker compose run --rm pipeline-runner python -m pipeline_runner security
docker compose run --rm pipeline-runner python -m pipeline_runner full
```

Run against a specific repository checkout:

```bash
docker compose run --rm pipeline-runner python -m pipeline_runner pr-review /path/to/repo
```

Or run directly with Poetry (development):

```bash
cd tools/pipeline_runner
poetry run python -m pipeline_runner security /path/to/repo
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for how pipelines fit into the overall system and [WORKFLOW.md](WORKFLOW.md) for when pipelines are triggered.
