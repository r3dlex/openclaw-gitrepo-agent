# CLAUDE.md - Developer Guide

> This file is for developers and AI assistants working ON the GitRepo Agent codebase.
> For the agent's own operational instructions → see `AGENTS.md`

## Quick Start

```bash
# 1. Clone and configure
cp .env.example .env  # Fill in your values
cp config/repos.example.json config/repos.json  # Configure watched repos

# 2. Run everything (zero-install via Docker)
docker compose up -d

# 3. Run pipelines
docker compose run --rm pipeline-runner python -m pipeline_runner full

# 4. Process PRs
docker compose run --rm pipeline-runner python -m pipeline_runner pr-review
```

## Repository Structure

```
├── CLAUDE.md              ← You are here (developer guide)
├── AGENTS.md              ← Agent operational instructions (read by the openclaw agent)
├── SOUL.md                ← Agent identity and principles
├── IDENTITY.md            ← Agent name and role
├── HEARTBEAT.md           ← Periodic task definitions
├── TOOLS.md               ← Environment-specific tool notes
├── USER.md                ← About the human operator
├── spec/                  ← Detailed specifications (progressive disclosure)
│   ├── ARCHITECTURE.md    ← System architecture overview
│   ├── PIPELINES.md       ← Pipeline definitions
│   ├── WORKFLOW.md        ← Operational workflow
│   ├── SCORING.md         ← PR scoring system
│   ├── TROUBLESHOOTING.md ← Common issues
│   ├── LEARNINGS.md       ← Accumulated knowledge
│   ├── COMMUNICATION.md   ← Reporting and notifications
│   └── SAFETY.md          ← Security and safety rules
├── .archgate/adrs/        ← Architecture Decision Records
├── config/                ← Runtime configuration
│   └── repos.example.json ← Watched repos template
├── input/                 ← Task queue
│   └── TASK.md            ← PRs to process
├── lib/                   ← Elixir modules (core orchestration)
│   └── gitrepo_agent/
│       ├── application.ex
│       ├── repo_manager.ex
│       ├── pr_evaluator.ex
│       ├── stats_collector.ex
│       ├── scoring.ex
│       ├── report_generator.ex
│       └── task_processor.ex
├── tools/                 ← Python tooling
│   └── pipeline_runner/   ← Validation pipelines (Poetry)
├── docker-compose.yml     ← Zero-install orchestration
├── Dockerfile             ← Multi-stage build (Elixir + Python)
└── mix.exs                ← Elixir project definition
```

## Two Audiences, Two Entry Points

| Audience | Entry Point | Purpose |
|----------|-------------|---------|
| **Developers** working on the agent code | `CLAUDE.md` (this file) | How to build, test, contribute |
| **The openclaw agent** running autonomously | `AGENTS.md` → `SOUL.md` → `spec/` | How to operate, what to do |

## Architecture

The agent has two runtime layers:

1. **Elixir/OTP** (`lib/gitrepo_agent/`) — Core orchestration: repo management, task processing, scheduling, report generation. Uses OTP supervision trees for reliability.

2. **Python** (`tools/pipeline_runner/`) — Validation pipelines: security scanning, code quality, ADR checks, PR scoring. Managed by Poetry.

Both run in Docker containers. See `spec/ARCHITECTURE.md` for full details.

## Key Decisions (ADRs)

All significant decisions are in `.archgate/adrs/`. Key ones:

- **ARCH-001**: Elixir for orchestration (concurrency, reliability)
- **ARCH-002**: Docker zero-install (no local deps required)
- **ARCH-003**: 5-category weighted PR scoring
- **ARCH-005**: Secrets never in git

## Environment Variables

All configuration lives in `.env`. See `.env.example` for the full list. Key variables:

- `GITREPO_AGENT_DATA_DIR` — where repos, logs, and scoring data live
- `ADO_PAT` / `GITHUB_TOKEN` — VCS authentication
- `TELEGRAM_BOT_TOKEN` — report delivery
- `OPENCLAW_AGENT_CLAUDE_DIR` — ARCHITECT integration

## Running Pipelines

```bash
# Full validation
docker compose run --rm pipeline-runner python -m pipeline_runner full

# Individual pipelines
docker compose run --rm pipeline-runner python -m pipeline_runner security
docker compose run --rm pipeline-runner python -m pipeline_runner architecture
docker compose run --rm pipeline-runner python -m pipeline_runner quality
docker compose run --rm pipeline-runner python -m pipeline_runner adr-check

# PR review
docker compose run --rm pipeline-runner python -m pipeline_runner pr-review
```

## Testing

```bash
# Elixir tests
docker compose run --rm agent mix test

# Python tests
docker compose run --rm pipeline-runner poetry run pytest

# Full CI
docker compose run --rm pipeline-runner python -m pipeline_runner ci
```

## Contributing

1. All secrets in `.env`, never in code
2. Document architectural decisions as ADRs in `.archgate/adrs/`
3. Run `full` pipeline before committing
4. Keep progressive disclosure: CLAUDE.md → spec/ → ADRs
