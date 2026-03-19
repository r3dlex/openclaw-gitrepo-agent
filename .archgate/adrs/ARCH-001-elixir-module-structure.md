# ARCH-001: Elixir Module Structure

**Status:** accepted
**Date:** 2026-03-19
**Deciders:** GitRepo Agent Team

## Context
Need reliable concurrency for multi-repo sync and PR processing.

## Decision
Use Elixir/OTP for core orchestration. Elixir modules in lib/gitrepo_agent/ with OTP supervision trees.

## Consequences
Requires Elixir runtime (mitigated by Docker zero-install).
