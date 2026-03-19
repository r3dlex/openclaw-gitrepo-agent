# .archgate - Architecture Decision Records

ADRs document significant architectural decisions for this project.

## Convention

- Files: `ARCH-NNN-short-title.md`
- Status: `proposed` → `accepted` → `deprecated` or `superseded`
- ADRs are immutable once accepted (create new ADR to supersede)

## Index

| ADR | Title | Status |
|-----|-------|--------|
| ARCH-001 | Elixir Module Structure | accepted |
| ARCH-002 | Zero-Install Containers | accepted |
| ARCH-003 | PR Scoring System | accepted |
| ARCH-004 | Pipeline Runner (Python) | accepted |
| ARCH-005 | Secrets Never in Git | accepted |
| ARCH-006 | Progressive Disclosure | accepted |
| ARCH-007 | Multi-VCS Support | accepted |

## Validation

Run `docker compose run --rm pipeline-runner python -m pipeline_runner adr-check` to validate ADRs.
