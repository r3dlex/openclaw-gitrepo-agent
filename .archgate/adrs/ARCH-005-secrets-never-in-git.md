# ARCH-005: Secrets Never in Git

**Status:** accepted
**Date:** 2026-03-19
**Deciders:** GitRepo Agent Team

## Context
Repo will be public on GitHub.

## Decision
No secrets ever appear in git. All secrets in .env (gitignored), .env.example has dummies, pipeline checks for leaked secrets.

## Consequences
Setup requires copying .env.example and filling values.
