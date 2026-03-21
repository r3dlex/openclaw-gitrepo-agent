# ARCH-008: Inter-Agent Message Queue Integration

**Status:** Accepted
**Date:** 2026-03-20

## Context

The GitRepo Agent operates as part of the OpenClaw agent swarm — a network of specialized agents (mail, librarian, journalist, sysadmin, etc.) that need to communicate and coordinate. Previously, the agent had limited communication channels and no way to receive requests from other agents or discover what agents are online.

The OpenClaw Inter-Agent Message Queue (IAMQ) provides a centralized HTTP + WebSocket message bus running at `http://127.0.0.1:18790` with agent registration, heartbeats, inbox polling, and pub/sub messaging.

## Decision

Integrate with the IAMQ via a new `GitrepoAgent.MqClient` GenServer that:

1. **Registers** as `gitrepo_agent` on OTP application startup
2. **Sends heartbeats** every 60s (configurable via `IAMQ_HEARTBEAT_MS`)
3. **Polls inbox** every 30s (configurable via `IAMQ_POLL_MS`) for incoming messages
4. **Routes requests** — handles PR review requests, status queries, and scoring requests from other agents
5. **Broadcasts** weekly reports and security alerts to all agents
6. **Uses HTTP API** (via `Req`) rather than WebSocket for simplicity and statelessness

The MqClient is the first child in the supervision tree, ensuring it registers before other subsystems start processing.

## Consequences

**Positive:**
- GitRepo Agent is now discoverable by all other agents in the swarm
- Other agents can request PR reviews, repo status, and scoring data
- Weekly reports reach all agents via broadcast, full reports delivered to `librarian_agent` via IAMQ
- Security alerts broadcast immediately to the entire swarm
- Graceful degradation: if IAMQ is down, agent retries registration and continues local operations

**Negative:**
- Adds a runtime dependency on the IAMQ service being available
- Polling-based inbox (every 30s) introduces slight latency vs. WebSocket push
- Additional env vars to configure (`IAMQ_HTTP_URL`, `IAMQ_AGENT_ID`, etc.)

**Trade-offs:**
- Chose HTTP polling over WebSocket for simplicity — WebSocket would give real-time push but adds connection management complexity. Can upgrade later if latency matters.
- Chose to start MqClient first in the supervision tree so registration happens early, but with a 2s delay to let the IAMQ service initialize if starting concurrently.
