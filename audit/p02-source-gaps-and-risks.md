# P02 - OSINT Source Gaps and Risk Analysis

## Executive Summary

This document evaluates the operational, credential, rate-limiting, licensing, and architectural risks associated with external OSINT data sources integrated into World Monitor (`world-monitor` v2.10.0).

While the system is designed to run without mandatory API keys for basic map and news browsing, deep intelligence layers (real-time conflict event streams, satellite thermal detection, live maritime vessel AIS, internet outage detection, and cloud AI summarization) depend on 18 optional or required credentials.

---

## 1. Source Availability & Credential Dependency Risks

### 1.1 Credential-Gated Intelligence Outages
When required environment variables are absent, the application gracefully degrades by returning empty payloads, cached snapshots, or falling back to secondary providers. However, this creates silent coverage gaps if unmonitored:
- **ACLED Conflict Events (`ACLED_EMAIL`/`ACLED_PASSWORD`)**: Missing credentials force fallback to UCDP. While UCDP covers state/non-state armed violence, tactical event-level granularity is reduced in non-UCDP countries.
- **NASA FIRMS Wildfire Detections (`NASA_FIRMS_API_KEY`)**: Without a FIRMS API key, the satellite fire layer cannot pull live thermal anomalies and relies solely on historical server baselines.
- **AISStream Real-Time Vessel Tracking (`AISSTREAM_API_KEY`)**: Without an AISStream key, real-time ship positions and dark vessel alerts are unavailable, falling back to static IMF PortWatch transit counts.
- **Cloudflare Radar Internet Outages (`CLOUDFLARE_API_TOKEN`)**: Cloudflare Radar requires a paid API token. Without it, the BGP anomaly and internet outage panel returns an empty list.

---

## 2. Single-Point-of-Failure (SPOF) Analysis for Critical Domains

| Intelligence Domain | Primary Provider | SPOF Risk Level | Mitigation & Fallback Strategy |
|---|---|---|---|
| **Conflict & Unrest** | ACLED / UCDP | Low | Multi-source blend: ACLED + UCDP + OREF Sirens + Telegram OSINT. UCDP acts as primary fallback. |
| **Maritime Tracking** | AISStream | Medium | IMF PortWatch & CorridorRisk supply static/hourly transit counts when WebSocket stream drops. |
| **Aviation & Military Flights** | OpenSky / Wingbits | Low | Dual provider failover: OpenSky anonymous tier -> Wingbits API -> computed NOTAM closures. |
| **Earthquakes & Disasters** | USGS GeoJSON | Low | USGS GeoJSON is public domain with high availability; fallback to static fault lines. |
| **Corporate Intelligence** | SEC EDGAR | Medium | SEC CIK registry is authoritative. Unresolved tickers return clean `sources: []` rather than guessing. |
| **AI Synthesis & Briefs** | Google Gemini API | Low | 4-tier chain: Local Ollama -> Groq -> OpenRouter -> browser-side Transformers.js T5 ONNX model. |

---

## 3. Rate Limiting, Quota Caps, and Cost/Egress Inflation Risks

### 3.1 Uncredentialed Provider Rate Limits
- **Yahoo Finance**: Uncredentialed HTTP requests require 150ms staggering (`server/worldmonitor/market/handler.ts`) to prevent HTTP 429 rate-limiting storms across stock, commodity, and crypto feeds.
- **CoinGecko**: Free tier rate limits frequently trigger HTTP 429; CoinPaprika acts as automatic fallback.
- **AviationStack**: Free tier monthly quota caps can starve airport delay updates if poll frequencies are set too high.

### 3.2 Egress & CDN Cost Inflation ("The Lever Test")
- **Hydration Payload Sizing**: The `/api/bootstrap` endpoint hydrates fast and slow data tiers in single batch reads. If un-cached or un-sliced canonical datasets are shipped to the client instead of pruned view keys, egress costs scale linearly with client connections.
- **Redis Lock Coalescing**: `cachedFetchJson()` coalesces concurrent cache misses using Redis `SET NX` locks. If Redis connection drops, concurrent requests fall through to upstream APIs, risking upstream rate-limit bans or API quota depletion.

---

## 4. Licensing, Redistribution, and Provider Terms Compliance

- **AGPL-3.0-only Source License**: World Monitor is released under AGPL-3.0-only. All modifications and distribution must preserve copyleft and source availability.
- **SEC EDGAR Fair Use**: Requests to SEC EDGAR must include a custom, contact-bearing `User-Agent` header (`server/worldmonitor/intelligence/handler.ts`) per SEC fair-use regulations.
- **ACLED Terms of Use**: Commercial redistribution of ACLED conflict data requires a commercial licence. The seed script supports ACLED OAuth token auto-refresh for research/institutional account compliance.
- **OpenSky Network Open Data**: OpenSky state vectors are used in compliance with open-access research terms.

---

## 5. Data Freshness, Staleness Cascades, and Seed Monitoring Gaps

- **Seed Metadata Integrity**: `atomicPublish()` (`scripts/_seed-utils.mjs`) writes `seed-meta:<key>` with `{ fetchedAt, recordCount }`.
- **Staleness Cascades**:
  - `api/health.js` monitors key staleness against domain-specific `maxStaleMin` SLAs.
  - If a seeder fails (e.g. `seed-fire-detections.mjs` due to missing key), `seed-meta` marks the key `STALE` or `EMPTY`, raising health alerts without crashing the edge function.
- **Self-Hosted Redis Proxy Limitation**:
  - The bundled self-hosted Redis REST proxy (`docker/redis-rest-proxy.mjs`) rejects Lua scripts (`EVAL`/`EVALSHA`). `@upstash/ratelimit` automatically falls back to non-Lua fixed-window limiting (`INCR` + `EXPIRE NX`).

---

## 6. Air-Gapped / Privacy Mode Coverage Gaps

- **Local Ollama Support**: When running in privacy/air-gapped mode with Ollama (`http://localhost:11434`), AI summarization and classification execute entirely locally.
- **Gaps in Air-Gapped Mode**: Live external API streams (ADS-B flights, AIS ships, real-time RSS, financial quotes) require network connectivity. In a strictly air-gapped environment without internet access, these panels will rely entirely on pre-seeded Redis snapshots or static datasets (`data/`).
