# Communication

How the GitRepo Agent communicates results to humans and other agents.

## Delivery Channels

### Telegram

Used for time-sensitive notifications and concise summaries.

- **Weekly reports**: Monday morning summary of all repo activity
- **Urgent security alerts**: Immediate notification for critical/high severity findings
- **PR processing summaries**: Brief verdict after each PR evaluation

### Librarian Agent

Full markdown reports are dropped into `$LIBRARIAN_DATA_FOLDER/input/` for long-term storage and retrieval.

- The Librarian agent indexes and catalogs these reports
- Reports remain available for historical queries and trend analysis
- This is the authoritative archive of all agent output

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

## Telegram Message Format

Messages are concise with score and verdict upfront. Example PR summary:

```
PR #456 — org/repo-name
Score: 78% | Verdict: approve_with_comments

Security: 85 | Design: 72 | Style: 80 | Practices: 75 | Docs: 70

Key findings:
- Missing error handling in payment module
- Test coverage below threshold for new endpoint

Full report: delivered to Librarian
```

Example weekly summary:

```
Weekly Report — 2026-03-16

Repos monitored: 12 | PRs evaluated: 23

Top scores:
  alice (92 avg) | bob (85 avg)

Needs attention:
  charlie (declining, 58 avg)

Security alerts: 1 critical (PR #789, repo-name)
AI-assisted commits: 7 of 45 total

Full report: delivered to Librarian
```

## Group Notifications

When sending to Telegram groups:

- Be concise, no more than 10 lines per message
- Lead with the most important information (security alerts first)
- Link to the full report rather than including all details
- Use a single message per PR (do not split across messages)

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
