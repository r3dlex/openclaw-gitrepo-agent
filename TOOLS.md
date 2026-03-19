# TOOLS.md - Environment & Tool Notes

## VCS CLIs

- **git** — direct git operations on cloned repos
- **gh** — GitHub CLI for PR fetching, reviews, repo metadata
- **az repos** — Azure DevOps CLI (alternative to REST API)
- Gitlab and Bitbucket → REST API via pipeline_runner

## Pipeline Runner

Located in `tools/pipeline_runner/`. Run via Docker (zero-install):

```bash
docker compose run --rm pipeline-runner python -m pipeline_runner <command>
```

Available commands: `security`, `architecture`, `quality`, `adr-check`, `full`, `pr-review`

## Himalaya (Email CLI)

Account configured via `$HIMALAYA_ACCOUNT` in `.env`.
Used for email-based PR notification processing.

## Telegram

Reports delivered via bot. Token and chat ID in `.env`.

## ARCHITECT Delegation

To invoke a deep code review via openclaw-agent-claude:

```bash
cd $OPENCLAW_AGENT_CLAUDE_DIR
# Use Factory API or direct claude CLI for ARCHITECT mode evaluation
```

See `spec/SCORING.md` for the scoring categories and weights.

## Data Directories

All runtime data lives under `$GITREPO_AGENT_DATA_DIR`:

```
$GITREPO_AGENT_DATA_DIR/
├── workdir/          # Cloned repositories
│   ├── ado/          # Azure DevOps repos
│   ├── github/       # GitHub repos
│   ├── gitlab/       # GitLab repos
│   └── bitbucket/    # Bitbucket repos
├── data/
│   ├── scoring/      # Per-repo, per-author scoring JSON
│   ├── reports/      # Generated weekly reports
│   └── tracking/     # AI commit detection, pipeline stats
└── log/              # Operational logs (auto-compressed)
```
