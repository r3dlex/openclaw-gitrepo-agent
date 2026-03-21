# Operational Workflow

The GitRepo Agent operates in a continuous cycle of sync, process, evaluate, report, and maintain. This document describes the full operational flow.

## Phase 1: Repository Sync

**Trigger:** Scheduled interval (configurable per repo in `repos.json`).

1. Iterate through all watched repositories in `repos.json`
2. For each repo:
   - Clone or pull latest into `$GITREPO_AGENT_DATA_DIR/workdir/<repo-name>/`
   - Detect new commits since last sync (compare HEAD references)
   - Detect new or updated PRs via VCS API
   - Store sync metadata (last commit SHA, timestamp, PR list)
3. Queue detected changes for task processing

If a repo sync fails, log the error and continue with remaining repos. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common sync failures.

## Phase 2: Task Processing

**Trigger:** New items in queue or manual `input/TASK.md` entry.

1. Read `input/TASK.md` for manually submitted tasks
2. Validate that referenced repositories are in the watched list
3. Fetch PR data from VCS API (diff, metadata, comments, linked work items)
4. Merge manual tasks with auto-detected changes from Phase 1
5. Prioritize: security-flagged items first, then by PR age

Task format in `input/TASK.md` (under the `## Queue` section):

```markdown
- [ ] github:org/repo-name#456 priority=high
- [ ] ado:myorg/myproject#789
- [ ] gitlab:team/repo!123 priority=low
```

See `input/TASK.md` for the full format specification.

## Phase 3: PR Evaluation

**Trigger:** Queued PRs ready for evaluation.

1. Run the `pr-review` pipeline (see [PIPELINES.md](PIPELINES.md))
2. Score across 5 categories with weighted totals (see [SCORING.md](SCORING.md))
3. If the PR touches architectural boundaries or scores below 70% on Design:
   - Delegate to `openclaw-agent-claude` in ARCHITECT mode
   - Merge ARCHITECT findings into the evaluation
4. Generate verdict: approve, approve_with_comments, request_changes, or reject
5. Persist scoring data to `$GITREPO_AGENT_DATA_DIR/data/scoring/`
6. Update per-author rolling scores

## Phase 4: Reporting

**Trigger:** Evaluation complete, or weekly schedule.

### Per-PR Reports
1. Generate markdown report: `YYYY-MM-DD_pr_<id>.md`
2. Drop full report into `$LIBRARIAN_DATA_FOLDER/input/`
3. Send IAMQ response to requesting agent (or broadcast if auto-detected)

### Weekly Reports (Monday)
1. Aggregate all PR evaluations from the past week
2. Compute commit volumes per repo and per author
3. Calculate author score trends (improving/stable/declining)
4. Flag AI-assisted commits (see [SCORING.md](SCORING.md) for detection)
5. Generate `YYYY-MM-DD_weekly_report.md`
6. Deliver to Librarian and broadcast summary via IAMQ

See [COMMUNICATION.md](COMMUNICATION.md) for report formatting and delivery rules.

## Phase 5: Maintenance

**Trigger:** Daily scheduled job.

1. Compress logs older than 7 days into `$GITREPO_AGENT_DATA_DIR/log/compressed/`
2. Delete compressed logs older than 30 days
3. Clean stale workdir checkouts (repos removed from `repos.json`)
4. Update committer statistics aggregates
5. Verify data directory disk usage, alert if approaching limits

See [SAFETY.md](SAFETY.md) for data retention policies.

## Task Lifecycle

```
PR detected or entered in TASK.md
  -> Queued for processing
  -> Evaluated and scored
  -> Removed from TASK.md (if manually entered)
  -> Scoring data persisted to data/scoring/
  -> Report generated and delivered
  -> Tracking entry stored in data/tracking/
```

Manual TASK.md entries are removed after processing. Auto-detected PRs are tracked by their VCS ID to prevent re-processing.

## Weekly Cycle Summary

| Day       | Activity                                           |
|-----------|---------------------------------------------------|
| Monday    | Weekly report generation and delivery              |
| Daily     | Repository sync, PR processing, maintenance        |
| On-demand | Manual TASK.md entries processed within next cycle |
