# ARCH-006: Progressive Disclosure

**Status:** accepted
**Date:** 2026-03-19
**Deciders:** GitRepo Agent Team

## Context
Too much info in one file is overwhelming.

## Decision
Use progressive disclosure for documentation. AGENTS.md is entry point, references spec/ files which reference ADRs. Agent reads top-level first, digs into spec/ as needed.

## Consequences
Information is layered, not duplicated.
