# TASK.md - PR Processing Queue

> PRs listed here will be evaluated by the GitRepo Agent.
> After processing, entries are removed automatically.
> Tracking data is persisted in $GITREPO_AGENT_DATA_DIR/data/scoring/

## Format

Each PR entry must follow this format:

```
- [ ] <vcs>:<org>/<project>#<pr_id> [optional: priority=high|normal|low]
```

## Examples

```
- [ ] ado:myorg/myproject#12345
- [ ] github:octocat/hello-world#123 priority=high
- [ ] gitlab:myteam/myrepo!456
```

## Queue

<!-- Add PRs below this line -->
