# HEARTBEAT.md - Periodic Tasks

## On Every Heartbeat

1. Send heartbeat to IAMQ (`POST /heartbeat`) — stay registered in the swarm
2. Poll IAMQ inbox for incoming messages — process requests from other agents
3. Check `input/TASK.md` for new PRs to process
4. Sync watched repositories that haven't been updated in the last interval
5. Process any pending PR evaluations

## Every 4 Hours

6. Check pipeline status for watched repos (CI pass/fail rates)
7. Detect new PRs in watched repos that aren't in the task list yet
8. Query IAMQ for registered agents (`GET /agents`) — update awareness of the swarm

## Daily (First Heartbeat After 09:00)

9. Compress logs older than `$LOG_COMPRESS_AFTER_DAYS` days
10. Clean up logs older than `$LOG_RETENTION_DAYS` days
11. Update committer activity data for all watched repos

## Weekly (Monday, First Heartbeat After 09:00)

12. Generate weekly commit volume report for all watched repos
13. Generate author activity and scoring summary
14. Detect AI-assisted commits and report percentages
15. Deliver reports to `$LIBRARIAN_DATA_FOLDER/input/`
16. Broadcast weekly report summary to IAMQ (all agents)
17. Archive processed scoring data older than 1 year

## Heartbeat Response Rules

- If tasks were processed → report what was done
- If repos were synced → report commit counts
- If nothing needs attention → reply `HEARTBEAT_OK`
- Never reach out between 23:00-08:00 unless a security-critical PR is detected
