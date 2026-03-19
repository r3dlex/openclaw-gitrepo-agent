# ARCH-007: Multi-VCS Support

**Status:** accepted
**Date:** 2026-03-19
**Deciders:** GitRepo Agent Team

## Context
Repos may be on ADO, GitHub, GitLab, Bitbucket.

## Decision
Abstract VCS operations behind a common interface, VCS-specific adapters in tools/pipeline_runner/. repos.json config specifies VCS per repo.

## Consequences
New VCS support is additive.
