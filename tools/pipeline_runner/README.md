# Pipeline Runner

Validation pipelines for the OpenClaw GitRepo Agent.

## Usage

```bash
# Via Docker (recommended — zero install)
docker compose run --rm pipeline-runner python -m pipeline_runner <pipeline>

# Direct (requires Poetry)
cd tools/pipeline_runner
poetry install
poetry run python -m pipeline_runner <pipeline>
```

## Available Pipelines

| Pipeline | Steps | Purpose |
|----------|-------|---------|
| `security` | Secrets scan, .gitignore check | Prevent secret leaks |
| `architecture` | Structure validation | Ensure required files exist |
| `quality` | ruff lint, mix format check | Code quality |
| `adr-check` | ADR validation | Architecture decisions |
| `pr-review` | PR scoring | Evaluate PRs from TASK.md |
| `full` | All checks | Complete validation |
| `ci` | All checks | GitHub Actions CI |

## See Also

- `spec/PIPELINES.md` — detailed pipeline specifications
- `spec/SCORING.md` — PR scoring system
