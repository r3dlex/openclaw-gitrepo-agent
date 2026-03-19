# Safety and Security Rules

Non-negotiable rules governing how the GitRepo Agent operates. These rules protect repositories, credentials, and data integrity.

## Secrets Protection

- **No secrets in git.** Never commit `.env` files, tokens, API keys, or credentials. The `security` pipeline enforces this.
- **No secrets in reports.** Redact all sensitive values in generated reports. Describe the finding type and location, never the value.
- **No secrets in chat messages.** Telegram messages must not contain tokens, passwords, or connection strings, even in truncated form.

See [COMMUNICATION.md](COMMUNICATION.md) for redaction examples.

## Repository Safety

- **No operating on repos in user's active workspace.** The agent works exclusively on its own clones in `$GITREPO_AGENT_DATA_DIR/workdir/`. Never modify files in a developer's working directory.
- **No destructive git operations.** The agent must never perform force push, branch deletion, history rewriting, or hard reset unless explicitly requested by a human operator. The agent's role is read-only analysis.
- **No commits to monitored repos.** The agent reads and evaluates; it does not push code changes.

## Data Integrity

- **Scoring data is append-only.** Historical scoring records must never be deleted or modified. New evaluations append to existing records. This ensures audit trail integrity.
- **No retroactive score changes.** Once a PR score is persisted, it is final. Re-evaluation creates a new record, not an update.

## Logging

- **Log everything.** All API calls to VCS providers, all scoring decisions, all reports generated, and all delivery attempts must be logged.
- **Log format:** timestamp, component, action, result, duration.
- **No secrets in logs.** Apply the same redaction rules as reports.

## Rate Limit Awareness

- **Respect VCS API limits.** Track remaining quota from response headers.
- **Implement exponential backoff.** When rate-limited, back off starting at 1 second, doubling up to 60 seconds.
- **Spread requests.** When syncing many repos, space API calls to avoid burst patterns.
- **Alert on sustained limiting.** If rate-limited for more than 5 minutes, send a Telegram alert.

See [LEARNINGS.md](LEARNINGS.md) for VCS-specific rate limit details.

## Credential Rotation

- **Detect expiring tokens.** When VCS API returns 401 or a token-expiry indicator, log the event and send a Telegram alert immediately.
- **No automatic token refresh.** Token rotation is a human operator task. The agent alerts but does not attempt to generate new tokens.
- **Grace period handling.** If a token fails, retry once after 30 seconds (in case of transient issues), then disable that repo's sync and alert.

## Data Retention

| Data Type        | Retention    | Action After Retention |
|-----------------|--------------|----------------------|
| Scoring records  | 1 year       | Archive to cold storage (do not delete) |
| Pipeline logs    | 7 days hot   | Compress after 7 days |
| Compressed logs  | 30 days      | Delete after 30 days |
| Workdir clones   | Until unused | Delete when repo removed from `repos.json` |
| Reports          | 1 year       | Retained in Librarian, local copies can be pruned |
| Tracking data    | 1 year       | Archive alongside scoring records |

See [WORKFLOW.md](WORKFLOW.md) Phase 5 for the maintenance process that enforces these policies.

## Failure Modes

When the agent encounters an unrecoverable error:

1. Log the full error with context
2. Send a Telegram alert with error summary
3. Skip the failing item and continue with remaining work
4. Never crash the entire agent due to a single repo or PR failure

The OTP supervision tree (see [ARCHITECTURE.md](ARCHITECTURE.md)) ensures individual process failures are isolated and restarted.
