# Learnings

Accumulated knowledge from operating the GitRepo Agent. This is a living document updated as new patterns and quirks are discovered.

## Patterns That Work

<!-- Add entries as they are discovered. Format:
- **Pattern name**: Description of what works well and why.
  - Context: when/where this applies
  - Example: concrete example if available
-->

_No entries yet. Add patterns here as they prove effective in production._

## Patterns to Avoid

<!-- Add entries as they are discovered. Format:
- **Anti-pattern name**: Description of what went wrong.
  - Symptom: how the problem manifested
  - Root cause: why it happened
  - Alternative: what to do instead
-->

_No entries yet. Add anti-patterns here as they are encountered._

## VCS-Specific Quirks

Known platform-specific behaviors that affect agent operation.

### Azure DevOps

- **API pagination requires continuation tokens.** ADO does not use page numbers. Responses include a `x-ms-continuationtoken` header when more results exist. The agent must pass this token in subsequent requests. Failing to paginate will silently return incomplete data.
- **Thread status semantics differ from GitHub.** ADO PR comment threads have a `status` field (active, fixed, won't fix, closed, etc.) that must be managed explicitly. Simply posting a comment does not resolve a thread.

### GitHub

- **Rate limiting: 5,000 requests/hour with token.** Unauthenticated requests are limited to 60/hour. The agent must track remaining quota via `X-RateLimit-Remaining` header and implement exponential backoff when approaching limits.
- **GraphQL API has separate rate limiting.** GitHub GraphQL uses a point-based system (5,000 points/hour) where different queries cost different amounts. Complex queries with nested connections consume points quickly.

### GitLab

- **Merge Requests vs Pull Requests.** GitLab uses "Merge Requests" (MRs) instead of "Pull Requests" (PRs). The API endpoint is `/merge_requests`, not `/pulls`. All internal references should normalize to "PR" for consistency, with translation at the adapter layer.
- **Project IDs are numeric.** Unlike GitHub (owner/repo) or ADO (org/project/repo), GitLab API calls require a numeric project ID or URL-encoded `namespace/project` path.

### Bitbucket

- **Pagination uses `next` URL.** Bitbucket API responses include a `next` field with the full URL for the next page. Do not construct pagination URLs manually.

## Scoring Calibration

Notes on tuning the scoring weights and thresholds.

<!-- Add calibration entries as adjustments are made. Format:
- **Date — Adjustment**: What was changed and why.
  - Before: previous values
  - After: new values
  - Rationale: what prompted the change
  - Outcome: observed effect (fill in after observation period)
-->

_No calibration adjustments yet. Current weights are the initial defaults defined in [SCORING.md](SCORING.md). Track adjustments here with before/after values and observed outcomes._
