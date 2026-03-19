# HEARTBEAT.md - Periodic Tasks

## On Every Heartbeat

1. Check `input/TASK.md` for new PRs to process
2. Sync watched repositories that haven't been updated in the last interval
3. Process any pending PR evaluations

## Every 4 Hours

4. Check pipeline status for watched repos (CI pass/fail rates)
5. Detect new PRs in watched repos that aren't in the task list yet

## Daily (First Heartbeat After 09:00)

6. Compress logs older than `$LOG_COMPRESS_AFTER_DAYS` days
7. Clean up logs older than `$LOG_RETENTION_DAYS` days
8. Update committer activity data for all watched repos

## Weekly (Monday, First Heartbeat After 09:00)

9. Generate weekly commit volume report for all watched repos
10. Generate author activity and scoring summary
11. Detect AI-assisted commits and report percentages
12. Deliver reports to Telegram and `$LIBRARIAN_DATA_FOLDER/input/`
13. Archive processed scoring data older than 1 year

## Heartbeat Response Rules

- If tasks were processed → report what was done
- If repos were synced → report commit counts
- If nothing needs attention → reply `HEARTBEAT_OK`
- Never reach out between 23:00-08:00 unless a security-critical PR is detected
