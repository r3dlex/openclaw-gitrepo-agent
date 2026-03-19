# ARCH-003: PR Scoring System

**Status:** accepted
**Date:** 2026-03-19
**Deciders:** GitRepo Agent Team

## Context
Need objective, reproducible PR quality assessment.

## Decision
Use a 5-category weighted scoring system. Security 25%, Design 25%, Practices 20%, Style 15%, Documentation 15%. Verdict thresholds: 90+ approve, 70-89 approve_with_comments, 50-69 request_changes, <50 reject.

## Consequences
Requires calibration over time, weights may need tuning.
