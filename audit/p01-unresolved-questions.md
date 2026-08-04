# P01 - Unresolved Questions and Runtime Verification Backlog

This document records architectural claims, operational assumptions, and integration paths that cannot be verified solely by static repository inspection and require active runtime verification.

---

## 1. Live Runtime Verification Backlog

### 1.1 Railway AIS Relay & WebSocket Stream Stability
- **Claim**: The Railway AIS relay (`scripts/ais-relay.cjs`) handles live vessel tracking, crossing detection, and seed loops without memory leaks or buffer overflows.
- **Verification Needed**: Observe the live WebSocket stream under peak vessel volume (>10,000 active vessels). Confirm queue backpressure limits and pre-gzipped snapshot cache behavior.
- **Risk Level**: Medium (High memory/CPU usage on relay container).

### 1.2 Upstash Redis Cache-Miss Coalescing & Rate Limiting
- **Claim**: `cachedFetchJson()` in `server/_shared/redis.ts` successfully coalesces concurrent cache misses using Redis SET NX locks.
- **Verification Needed**: Execute concurrent request load tests against Vercel Edge endpoints to verify lock release, cache hit ratios, and fallback behavior when Redis connection times out.
- **Risk Level**: Medium (Potential cache stampede on expired high-traffic keys).

### 1.3 Cloudflare Apex Dynamic Redirect Exemptions
- **Claim**: Cloudflare Dynamic Redirect rules allow `/mcp`, `/.well-known/mcp/server-card.json`, and `/.well-known/oauth-*` paths on the apex domain `worldmonitor.app` without issuing 301 redirects.
- **Verification Needed**: Run `mcp-live-smoke.yml` against the live production apex domain and confirm no 301 redirect fingerprint is returned for MCP clients.
- **Risk Level**: High (301 redirects break MCP transport handshakes and OAuth registration).

### 1.4 Wingbits & OpenSky Aviation Rate-Limit Failover
- **Claim**: Military flight tracking falls back gracefully from Wingbits API to OpenSky Network and cached Redis snapshots when rate limits (HTTP 429) are reached.
- **Verification Needed**: Simulate primary API 429 response in live sidecar/edge handlers and confirm seamless transition to fallback providers without UI panel error states.
- **Risk Level**: Low (Handled by circuit breaker and cached fallback).

### 1.5 Desktop Local Ollama Model Auto-Discovery
- **Claim**: The desktop Settings window (`public/settings.html`) discovers local Ollama models via `http://localhost:11434/v1/chat/completions` across Windows, macOS, and Linux.
- **Verification Needed**: Test desktop builds on clean machines running Ollama with custom model tags to verify auto-population and 4-tier summarization fallback execution.
- **Risk Level**: Low (Graceful fallback to cloud LLMs or browser-side Transformers.js).

### 1.6 Convex Vector Memory Search & Dodo Payments Sync
- **Claim**: Convex BaaS manages Dodo Payments subscription webhooks and updates reactive entitlement snapshots in real time.
- **Verification Needed**: Trigger test webhook events in Dodo Payments staging environment and verify instant entitlement snapshot replication to active client sessions.
- **Risk Level**: Medium (Billing entitlement delays could temporarily gate Pro subscribers).

---

## 2. Architectural Ambiguities & Boundary Edge Cases

1. **Self-Hosted Redis REST Proxy Lua Rejection**:
   - The self-hosted Redis REST proxy (`docker/redis-rest-proxy.mjs`) rejects Lua scripts (`EVAL`/`EVALSHA`). While rate-limiters fall back to fixed-window (`INCR` + `EXPIRE NX`), any new seeder relying on Lua scripts will fail on self-hosted deployments.
2. **Sidecar Local Port Binding Race**:
   - The desktop Node.js sidecar binds to a dynamic local port. On systems with strict local firewalls or port exhaustion, sidecar readiness probing may time out, forcing the desktop app into cloud API fallback mode.
3. **CII Country Attribution Coordinate Precision**:
   - Composite Instability Index (CII) coordinate attribution uses bounding-box approximations rather than exact point-in-polygon border geometries for overlapping border regions (e.g. RU/UA, IN/PK).
