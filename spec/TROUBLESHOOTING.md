# Troubleshooting

Common issues and their solutions, organized by subsystem.

## VCS Authentication Failures

**Symptom:** API calls return 401/403, repo sync fails with "authentication required".

| Cause | Solution |
|-------|----------|
| Token expired | Regenerate token in VCS provider, update `.env` |
| Wrong organization scope | Ensure token has access to the target org/project |
| Token lacks required permissions | GitHub: `repo`, `read:org`. ADO: `Code (Read)`, `Pull Request Threads (Read & Write)` |
| SSO not authorized | For GitHub with SSO, authorize the token for the org after creation |

Check token validity:
```bash
# GitHub
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Azure DevOps
curl -u :$ADO_PAT https://dev.azure.com/{org}/_apis/projects
```

## Docker Container Won't Start

**Symptom:** `docker compose up` fails or container exits immediately.

| Cause | Solution |
|-------|----------|
| Port conflict | Check `docker compose ps` and `lsof -i :<port>`, stop conflicting services |
| Volume mount errors | Ensure `$GITREPO_AGENT_DATA_DIR` exists and is writable |
| Image not built | Run `docker compose build` before `up` |
| Stale containers | `docker compose down` then `docker compose up` |
| Out of disk space | `docker system prune` to clean unused images/volumes |

## Pipeline Runner Errors

**Symptom:** `docker compose run --rm pipeline-runner` fails.

| Cause | Solution |
|-------|----------|
| Poetry dependencies out of sync | Run `docker compose build pipeline-runner` to rebuild |
| Python version mismatch | Check `pyproject.toml` for required Python version, ensure Dockerfile matches |
| Missing pipeline argument | Always specify `--pipeline <name>`, no default pipeline |
| Repo path not mounted | Ensure the repo path is accessible inside the container via volume mounts |

## Elixir Compilation Issues

**Symptom:** Elixir application fails to start, compilation errors.

| Cause | Solution |
|-------|----------|
| Dependencies not fetched | `docker compose run --rm gitrepo-agent mix deps.get` |
| Erlang/Elixir version mismatch | Check `.tool-versions` or `Dockerfile` for expected versions |
| Stale build artifacts | `docker compose run --rm gitrepo-agent mix clean` |
| Config errors | Verify `config/runtime.exs` references correct env vars |

## Repo Sync Failures

**Symptom:** Repository cloning or pulling fails.

| Cause | Solution |
|-------|----------|
| Network timeout | Check connectivity, increase git timeout in config |
| Large repository | Enable shallow clones in `repos.json` with `"shallow": true` |
| Branch not found | Verify branch names in `repos.json` match remote |
| Disk space | Check `$GITREPO_AGENT_DATA_DIR/workdir/` usage, clean stale repos |
| Git LFS files | Ensure git-lfs is installed in the Docker image if repos use LFS |

## Telegram Bot Not Sending

**Symptom:** Reports generated but no Telegram messages received.

| Cause | Solution |
|-------|----------|
| Invalid bot token | Verify `TELEGRAM_BOT_TOKEN` in `.env`, test with `/getMe` API call |
| Wrong chat_id | Use `/getUpdates` to find correct chat_id after sending a message to the bot |
| Rate limiting | Telegram limits ~30 msgs/sec. Agent should batch. Check logs for 429 errors |
| Bot not in group | Add bot to group and grant message permissions |
| Message too long | Telegram max is 4096 chars. Agent should truncate. Check for formatting errors |

Test Telegram connectivity:
```bash
curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"
```

## ARCHITECT Delegation Fails

**Symptom:** PR evaluation skips ARCHITECT review, logs show delegation error.

| Cause | Solution |
|-------|----------|
| openclaw-agent-claude not running | Start the Claude agent service |
| Wrong path configured | Verify `OPENCLAW_AGENT_CLAUDE_DIR` in `.env` points to the correct directory |
| Timeout | ARCHITECT reviews can take minutes; increase timeout in config |
| Input format mismatch | Check that PR diff is within size limits for Claude context |

See [WORKFLOW.md](WORKFLOW.md) Phase 3 for ARCHITECT delegation details.

## Data Directory Permissions

**Symptom:** Permission denied errors when writing to data directories.

| Cause | Solution |
|-------|----------|
| macOS Docker volume mount | Ensure `$GITREPO_AGENT_DATA_DIR` is under a Docker-accessible path |
| UID mismatch | Container user UID must match host directory owner |
| Read-only mount | Check `docker-compose.yml` volume definitions, remove `:ro` if present |

## Log Compression Failures

**Symptom:** Maintenance phase reports compression errors.

| Cause | Solution |
|-------|----------|
| Disk space full | Free space, then re-run maintenance |
| Permission denied | Check ownership of `$GITREPO_AGENT_DATA_DIR/log/` |
| Corrupted log file | Remove the specific file, agent will create fresh logs |

## Email/SMTP Issues

**Symptom:** Email notifications not sent.

| Cause | Solution |
|-------|----------|
| DavMail not running | Start DavMail service, verify it's listening on configured port |
| SMTP auth failed | Check SMTP credentials in `.env` |
| TLS/SSL mismatch | Ensure SMTP port matches security setting (587/STARTTLS, 465/SSL) |
| Firewall blocking | Verify outbound connections to SMTP port are allowed |

## SSH / Git Clone Failures

**Symptom:** `git clone` or `git fetch` fails with "Permission denied (publickey)" inside containers.

| Cause | Solution |
|-------|----------|
| SSH keys not mounted | Ensure `~/.ssh:/root/.ssh:ro` volume is in `docker-compose.yml` |
| SSH agent not forwarded | Keys must be file-based (not agent-only) for Docker mounts |
| Known hosts missing | Run `ssh-keyscan github.com >> ~/.ssh/known_hosts` on the host |
| Key permissions too open | `chmod 600 ~/.ssh/id_*` and `chmod 644 ~/.ssh/*.pub` on the host |
| Wrong key for repo | Check `~/.ssh/config` for `Host` entries matching the VCS domain |

Test SSH inside container:
```bash
docker compose run --rm agent ssh -T git@github.com
```

## General Debugging

1. Check container logs: `docker compose logs -f gitrepo-agent`
2. Check pipeline logs: `$GITREPO_AGENT_DATA_DIR/log/pipeline/`
3. Check agent log: `$GITREPO_AGENT_DATA_DIR/log/agent.log`
4. Verify environment: `docker compose run --rm gitrepo-agent env | sort`
5. Test VCS connectivity from inside container: `docker compose run --rm gitrepo-agent curl <api-url>`
