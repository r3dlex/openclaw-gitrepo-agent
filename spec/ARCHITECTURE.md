# Architecture Overview

The GitRepo Agent is a multi-VCS repository monitoring and PR evaluation system built on Elixir/OTP for orchestration and Python for validation pipelines. Everything runs in Docker containers with zero local installation required.

## Module Structure

### Elixir/OTP Core (`lib/gitrepo_agent/`)

The core orchestration layer uses OTP supervision trees for reliability:

- `GitrepoAgent.Application` — top-level supervisor, starts all subsystems
- `GitrepoAgent.MqClient` — inter-agent message queue client (registration, heartbeat, inbox polling, messaging)
- `GitrepoAgent.Scheduler` — cron-like scheduling for repo sync, weekly reports, maintenance
- `GitrepoAgent.RepoSync` — pulls latest from all watched repositories, detects new commits and PRs
- `GitrepoAgent.TaskProcessor` — reads `input/TASK.md`, dispatches work items
- `GitrepoAgent.Evaluator` — orchestrates PR scoring across all categories
- `GitrepoAgent.Reporter` — generates markdown reports, delivers to `librarian_agent` via IAMQ and broadcasts to the swarm
- `GitrepoAgent.VCS.Adapter` — behaviour module with implementations per VCS provider

### Python Pipeline Runner (`tools/`)

Validation pipelines run as a separate Python service managed via Poetry:

- `tools/pipeline_runner/` — main package
- `tools/pipeline_runner/pipelines/` — individual pipeline definitions (security, architecture, quality, etc.)
- `tools/pipeline_runner/reporters/` — output formatters for structured results
- `pyproject.toml` — Poetry dependency management

See [PIPELINES.md](PIPELINES.md) for pipeline definitions and execution details.

## Docker-Based Zero-Install

All components run in containers defined in `docker-compose.yml`:

- `gitrepo-agent` — Elixir/OTP application (orchestration, scheduling, reporting)
- `pipeline-runner` — Python validation pipelines
- Shared volumes for data exchange between containers

No local Elixir, Erlang, or Python installation needed. `docker compose up` is the only requirement.

## Data Directory Structure

All persistent data lives under `$GITREPO_AGENT_DATA_DIR`:

```
$GITREPO_AGENT_DATA_DIR/
  workdir/          # Cloned repositories (transient, can be rebuilt)
  data/
    scoring/        # Per-author and per-PR scoring history (append-only)
    tracking/       # Processed task tracking, committer stats
    reports/        # Generated markdown reports
  log/
    agent.log       # Main application log
    pipeline/       # Per-pipeline execution logs
    compressed/     # Archived logs (7+ days old)
```

## ADR Management

All significant architectural decisions are documented as Architecture Decision Records in `.archgate/adrs/` using the `ARCH-NNN` naming convention. The `architecture` pipeline validates ADR compliance. See [PIPELINES.md](PIPELINES.md) for the `adr-check` pipeline details.

## Multi-VCS Support

The agent monitors repositories across multiple version control hosting platforms:

| Provider     | API Used         | PR Model         |
|-------------|------------------|------------------|
| Azure DevOps | REST API v7      | Pull Requests    |
| GitHub       | REST + GraphQL   | Pull Requests    |
| GitLab       | REST API v4      | Merge Requests   |
| Bitbucket    | REST API 2.0     | Pull Requests    |

Each provider has a dedicated adapter implementing the `GitrepoAgent.VCS.Adapter` behaviour.

## Integration with openclaw-agent-claude

For complex PRs requiring deeper architectural review, the agent delegates to `openclaw-agent-claude` running in ARCHITECT mode. This provides:

- Architectural impact analysis
- Cross-module dependency review
- Design pattern recommendations

See [SCORING.md](SCORING.md) for when ARCHITECT delegation triggers and [WORKFLOW.md](WORKFLOW.md) for the delegation flow.

## Inter-Agent Communication

The agent participates in the OpenClaw agent swarm via the Inter-Agent Message Queue (IAMQ):

- **MqClient GenServer** — starts first in the supervision tree, registers with IAMQ
- **Heartbeat loop** — sends periodic heartbeats to maintain presence in the registry
- **Inbox polling** — checks for incoming messages from other agents on a configurable interval
- **Message routing** — dispatches incoming requests to appropriate handlers (PR review, status, scoring)
- **Outgoing messages** — broadcasts weekly reports, sends targeted responses, alerts on security issues

The IAMQ HTTP API runs at `$IAMQ_HTTP_URL` (default: `http://127.0.0.1:18790`).

## Report Delivery

Reports are delivered through two IAMQ channels:

- **Librarian agent** — full markdown reports sent to `librarian_agent` via IAMQ as structured JSON with base64-encoded attachments (images, charts, supplementary files). No shared filesystem required.
- **Swarm broadcast** — summary messages sent to all agents in the swarm via IAMQ broadcast.

See [COMMUNICATION.md](COMMUNICATION.md) for report formats and delivery rules.

## Configuration

- `repos.json` — list of watched repositories with VCS type, URL, branch filters, and sync frequency
- `.env` — credentials for VCS APIs, IAMQ connection settings, ARCHITECT evaluator path

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common configuration issues.
