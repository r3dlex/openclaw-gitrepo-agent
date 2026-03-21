# Communication

How the GitRepo Agent communicates results to humans and other agents.

## Delivery Channels

### Librarian Agent

Full markdown reports are dropped into `$LIBRARIAN_DATA_FOLDER/input/` for long-term storage and retrieval.

- The Librarian agent indexes and catalogs these reports
- Reports remain available for historical queries and trend analysis
- This is the authoritative archive of all agent output

### Inter-Agent Message Queue (IAMQ)

The agent communicates with other OpenClaw agents via the centralized message queue at `$IAMQ_HTTP_URL`.

**Outgoing messages:**

- **Weekly report broadcast** — summary sent to all agents every Monday via `type: "info"`, `priority: "NORMAL"`
- **Security alerts** — urgent broadcast when a critical/high severity finding is detected via `type: "error"`, `priority: "URGENT"`
- **PR score responses** — sent to the requesting agent when they ask for a PR review via `type: "response"`
- **Status responses** — sent when another agent queries repo status via `type: "response"`

**Incoming messages handled:**

| Subject Pattern | Action |
|---|---|
| `pr-review`, `PR review` | Queue the referenced PR for evaluation |
| `repo-status`, `status` | Respond with current repo sync status |
| `score`, `scoring` | Return scoring data for requested repo/author |

**Message format:**

```json
{
  "from": "gitrepo_agent",
  "to": "broadcast",
  "type": "info",
  "priority": "NORMAL",
  "subject": "Weekly GitRepo Report — 2026-03-20",
  "body": "Repos: 12 | PRs evaluated: 23 | Security alerts: 1\n\nTop: alice (92 avg) | Needs attention: charlie (58 avg)"
}
```

## Report Format

All reports follow progressive disclosure: summary first, then details, then raw data.

```
1. Summary    — one-line verdict, score, and key finding
2. Details    — category breakdowns, notable findings, recommendations
3. Raw data   — full pipeline output, file-level findings (in Librarian reports only)
```

## Report Naming

| Report Type   | Filename Pattern                    |
|---------------|-------------------------------------|
| Weekly report | `YYYY-MM-DD_weekly_report.md`       |
| PR evaluation | `YYYY-MM-DD_pr_<id>.md`            |
| Security alert| `YYYY-MM-DD_security_alert_<id>.md` |

## IAMQ Message Examples

### PR Score Summary (sent to requesting agent or broadcast)

```json
{
  "from": "gitrepo_agent",
  "to": "main",
  "type": "response",
  "priority": "NORMAL",
  "subject": "PR score: org/repo-name#456",
  "body": "Score: 78% | Verdict: approve_with_comments\n\nSecurity: 85 | Design: 72 | Style: 80 | Practices: 75 | Docs: 70\n\nKey findings:\n- Missing error handling in payment module\n- Test coverage below threshold for new endpoint\n\nFull report: delivered to Librarian"
}
```

### Weekly Report Broadcast

```json
{
  "from": "gitrepo_agent",
  "to": "broadcast",
  "type": "info",
  "priority": "NORMAL",
  "subject": "Weekly GitRepo Report — 2026-03-16",
  "body": "Repos monitored: 12 | PRs evaluated: 23\n\nTop scores: alice (92 avg) | bob (85 avg)\nNeeds attention: charlie (declining, 58 avg)\n\nSecurity alerts: 1 critical (PR #789, repo-name)\nAI-assisted commits: 7 of 45 total\n\nFull report: delivered to Librarian"
}
```

### Security Alert (urgent broadcast)

```json
{
  "from": "gitrepo_agent",
  "to": "broadcast",
  "type": "error",
  "priority": "URGENT",
  "subject": "Security alert: org/repo-name#789",
  "body": "Critical security finding in PR #789\n\nFinding: Hardcoded API key detected\nFile: src/config/api.py, line 23\nValue: [REDACTED]\n\nVerdict: reject"
}
```

## Broadcast Rules

When broadcasting to the swarm:

- Be concise — keep the body under 500 characters for summaries
- Lead with the most important information (security alerts first)
- Reference the full Librarian report rather than including all details
- Use a single message per PR (do not split across messages)
- Use `priority: "URGENT"` only for security-critical findings

## Content Safety Rules

Reports and messages must never include:

- Secrets, tokens, API keys, or passwords (even partial)
- Full email addresses (use first name or username only)
- Internal network paths or IP addresses
- Raw credentials from `.env` files
- Customer or user data found in repositories

If a security finding involves a secret, describe the type and location but redact the value:

```
Finding: Hardcoded API key detected
File: src/config/api.py, line 23
Value: [REDACTED — 40-char hex string matching API key pattern]
```

See [SAFETY.md](SAFETY.md) for the complete set of safety rules.
