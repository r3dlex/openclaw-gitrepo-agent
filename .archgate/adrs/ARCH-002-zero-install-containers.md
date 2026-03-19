# ARCH-002: Zero-Install Containers

**Status:** accepted
**Date:** 2026-03-19
**Deciders:** GitRepo Agent Team

## Context
Repo must be public-ready, users shouldn't need to install Elixir, Python, or system deps.

## Decision
Containerize everything. Docker Compose for all services.

## Consequences
Docker required, but nothing else.
