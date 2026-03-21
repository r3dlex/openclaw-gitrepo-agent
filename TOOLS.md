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

## ARCHITECT Delegation

To invoke a deep code review via openclaw-agent-claude:

```bash
cd $OPENCLAW_AGENT_CLAUDE_DIR
# Use Factory API or direct claude CLI for ARCHITECT mode evaluation
```

See `spec/SCORING.md` for the scoring categories and weights.

## Inter-Agent Message Queue (IAMQ)

The agent communicates with other OpenClaw agents via the central message queue:

```
Base URL: $IAMQ_HTTP_URL (default: http://127.0.0.1:18790)
Agent ID: $IAMQ_AGENT_ID (default: gitrepo_agent)
```

### Key Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/register` | POST | Register this agent |
| `/heartbeat` | POST | Keep-alive signal |
| `/send` | POST | Send a message to another agent |
| `/inbox/gitrepo_agent` | GET | Fetch incoming messages |
| `/inbox/gitrepo_agent?status=unread` | GET | Fetch unread messages only |
| `/messages/:id` | PATCH | Update message status (read/acted/archived) |
| `/agents` | GET | List all registered agents |
| `/status` | GET | Queue health summary |

### Elixir API (via `GitrepoAgent.MqClient`)

```elixir
# Send a message to another agent
MqClient.send_message("librarian_agent", "Weekly report", report_body, priority: "NORMAL")

# Broadcast to all agents
MqClient.broadcast("Security alert", alert_body, priority: "URGENT", type: "error")

# Check inbox
{:ok, messages} = MqClient.inbox("unread")

# Acknowledge a message
MqClient.ack(message_id, "acted")

# List all agents in the swarm
{:ok, agents} = MqClient.agents()
```

### Direct HTTP (curl)

```bash
# Register (minimal — MqClient sends full metadata automatically)
curl -X POST $IAMQ_HTTP_URL/register -H 'Content-Type: application/json' \
  -d '{"agent_id":"gitrepo_agent","name":"GitRepo Agent","emoji":"📊","description":"Multi-repo PR evaluation and scoring","capabilities":["pr_review","pr_scoring","security_scanning"]}'

# Send message
curl -X POST $IAMQ_HTTP_URL/send -H 'Content-Type: application/json' -d '{
  "from": "gitrepo_agent",
  "to": "librarian_agent",
  "type": "info",
  "priority": "NORMAL",
  "subject": "Weekly repo report",
  "body": "..."
}'

# Check inbox
curl $IAMQ_HTTP_URL/inbox/gitrepo_agent?status=unread

# List agents
curl $IAMQ_HTTP_URL/agents
```

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
