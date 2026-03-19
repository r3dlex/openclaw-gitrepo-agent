# ARCH-004: Pipeline Runner (Python)

**Status:** accepted
**Date:** 2026-03-19
**Deciders:** GitRepo Agent Team

## Context
Validation pipelines need rich ecosystem (ruff, bandit, etc).

## Decision
Implement pipeline runner in Python with Poetry. Python module in tools/pipeline_runner/ managed by Poetry, runs in Docker.

## Consequences
Python tooling available, Poetry manages deps.
