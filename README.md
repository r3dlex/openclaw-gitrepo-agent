# OpenClaw GitRepo Agent

Autonomous repository sentinel that monitors, evaluates, and reports on git repositories across multiple version control systems.

## What It Does

- **Watches repositories** — clones and syncs repos from Azure DevOps, GitHub, GitLab, Bitbucket
- **Evaluates Pull Requests** — 5-category weighted scoring (Security, Design, Practices, Style, Documentation)
- **Tracks committers** — per-author scoring with a rolling 1-year window
- **Generates weekly reports** — commit volumes, author activity, pipeline stability, AI-assisted commit detection
- **Detects risks** — flags security-sensitive changes and badly-written commits
- **Delegates deep reviews** — invokes ARCHITECT mode from [openclaw-agent-claude](https://github.com/openclaw/openclaw-agent-claude) for thorough code evaluation
- **Delivers reports** — via Telegram and to the Librarian agent

## Quick Start

```bash
# 1. Clone
git clone https://github.com/openclaw/openclaw-gitrepo-agent.git
cd openclaw-gitrepo-agent

# 2. Configure
cp .env.example .env          # Fill in your credentials
cp config/repos.example.json config/repos.json  # Add repos to watch

# 3. Run (zero-install via Docker)
docker compose up -d

# 4. Run validation pipelines
docker compose run --rm pipeline-runner python -m pipeline_runner full
```

**Requirements:** Docker and Docker Compose. Nothing else — zero-install.

## Architecture

```
┌─────────────────────────────────────────────┐
│            OpenClaw GitRepo Agent            │
├──────────────────┬──────────────────────────┤
│  Elixir/OTP      │  Python Pipeline Runner  │
│  (lib/)          │  (tools/pipeline_runner/) │
│                  │                           │
│  • RepoManager   │  • Security scanning     │
│  • TaskProcessor │  • Architecture checks   │
│  • StatsCollect  │  • Quality linting       │
│  • Scoring       │  • ADR validation        │
│  • ReportGen     │  • PR review & scoring   │
└──────────────────┴──────────────────────────┘
         │                    │
    ┌────┴────┐          ┌───┴───┐
    │ Repos   │          │Reports│
    │(workdir)│          │       │
    └─────────┘          └───────┘
         ↕                   ↓
  ADO/GitHub/GitLab    Telegram + Librarian
```

## Repository Structure

```
├── CLAUDE.md              ← Developer guide (start here)
├── AGENTS.md              ← Agent operational instructions
├── SOUL.md                ← Agent identity and principles
├── IDENTITY.md            ← Agent name and role
├── spec/                  ← Detailed specifications
│   ├── ARCHITECTURE.md
│   ├── SCORING.md
│   ├── WORKFLOW.md
│   └── ...
├── .archgate/adrs/        ← Architecture Decision Records
├── lib/gitrepo_agent/     ← Elixir modules
├── tools/pipeline_runner/ ← Python validation pipelines
├── config/                ← Watched repos configuration
├── input/TASK.md          ← PR processing queue
├── docker-compose.yml     ← Zero-install orchestration
└── Dockerfile             ← Multi-stage build
```

## Pipelines

| Pipeline | Purpose |
|----------|---------|
| `security` | Secrets scan, .gitignore validation |
| `architecture` | Required files and structure |
| `quality` | Python linting (ruff), Elixir formatting |
| `adr-check` | ADR convention validation |
| `pr-review` | PR scoring from TASK.md |
| `full` | All checks combined |

```bash
docker compose run --rm pipeline-runner python -m pipeline_runner <pipeline>
```

## PR Scoring

PRs are scored on 5 weighted categories:

| Category | Weight | What's Checked |
|----------|--------|----------------|
| Security | 25% | Secrets, auth, input validation, OWASP |
| Design | 25% | Architecture, boundaries, SOLID |
| Practices | 20% | Testing, error handling, logging |
| Style | 15% | Naming, formatting, clean code |
| Documentation | 15% | PR description, comments, migration notes |

**Verdicts:** 90+ approve · 70-89 approve with comments · 50-69 request changes · <50 reject

## Documentation

| File | Audience | Purpose |
|------|----------|---------|
| [CLAUDE.md](CLAUDE.md) | Developers | Setup, contribution, testing |
| [AGENTS.md](AGENTS.md) | The agent | Operational instructions |
| [spec/](spec/) | Both | Detailed specifications |
| [.archgate/adrs/](.archgate/adrs/) | Both | Architecture decisions |

## License

MIT — see [LICENSE](LICENSE).
