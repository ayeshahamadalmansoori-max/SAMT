# P01 - Repository Architecture Audit

## Executive Summary

This architecture audit evaluates the checked-out **World Monitor** repository (`world-monitor` v2.10.0) based on repository evidence, configuration manifests, contracts, and documentation snapshot. World Monitor is a real-time global intelligence dashboard engineered as a TypeScript single-page application (SPA) with a dual-map rendering engine, a Proto-first HTTP RPC backend (sebuf), Vercel Edge Function gateways, background Railway relay/seeder services, Convex BaaS, and multi-platform Tauri 2.x desktop shells.

---

## 1. Applications, Packages, and Variants

### Applications and Sub-Packages
- **Root Application (`world-monitor` v2.10.0)**: Main repository root containing the core SPA, Vercel Edge Functions, sebuf backend, and desktop Tauri shell.
  - *Evidence*: `package.json` (`name: "world-monitor"`, `version: "2.10.0"`), `README.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Blog Platform (`blog-site/`)**: Astro-powered static blog located at `/blog` with 16+ SEO posts, integrated into the main build pipeline via npm postinstall and prebuild scripts.
  - *Evidence*: `package.json` (`"postinstall": "cd blog-site && npm ci --prefer-offline"`, `"build:blog"`), `AGENTS.md`, `ARCHITECTURE.md`, `CHANGELOG.md`.
  - *Status*: Implemented and Active.
- **Official CLI (`cli/`)**: Zero-dependency ESM command-line interface (`worldmonitor` / `wm`) for MCP tools and risk queries. Published to npm via OIDC trusted publishing.
  - *Evidence*: `package.json` (`"publish-cli"`), `cli/`, `AGENTS.md`, `ARCHITECTURE.md`, `README.md`.
  - *Status*: Implemented and Active.
- **Pro QA Application (`pro-test/`)**: Standalone marketing and QA web application package used for testing Pro features and landing pages.
  - *Evidence*: `package.json` (`"build:pro"`), `pro-test/`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Python SDK (`sdk/python/`)**: PyPI package `worldmonitor-sdk` providing zero-dependency access to World Monitor APIs.
  - *Evidence*: `package.json` (`"publish-python"`), `sdk/python/`, `ARCHITECTURE.md`, `README.md`.
  - *Status*: Implemented and Active.
- **Ruby SDK (`sdk/ruby/`)**: RubyGem `worldmonitor` published to RubyGems.
  - *Evidence*: `package.json` (`"publish-ruby"`), `sdk/ruby/`, `ARCHITECTURE.md`, `README.md`.
  - *Status*: Implemented and Active.
- **Go SDK (`sdk/go/`)**: Go module `github.com/koala73/worldmonitor/sdk/go`.
  - *Evidence*: `package.json` (`"publish-go"`), `sdk/go/`, `ARCHITECTURE.md`, `README.md`.
  - *Status*: Implemented and Active.
- **Consumer Prices Collector (`consumer-prices-core/`)**: Containerized Playwright scrapers for per-country baskets, running on Railway/Docker and publishing to Redis.
  - *Evidence*: `consumer-prices-core/Dockerfile`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Tauri Desktop Shell (`src-tauri/`)**: Tauri 2.x Rust application with a bundled Node.js sidecar (`src-tauri/sidecar/local-api-server.mjs`) for desktop deployment across macOS, Windows, and Linux.
  - *Evidence*: `src-tauri/tauri.conf.json`, `src-tauri/src/main.rs`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **CORS Preflight Worker (`workers/api-cors-preflight/`)**: Cloudflare Worker handling edge CORS preflight for `api.worldmonitor.app`.
  - *Evidence*: `workers/api-cors-preflight/wrangler.toml`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Convex BaaS (`convex/`)**: Cloud backend handling user state, API keys, Dodo Payments billing/entitlements, email/broadcast, contact forms, and vector memory.
  - *Evidence*: `convex/schema.ts`, `package.json`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.

### Application Variants
The application produces 6 distinct thematic variants controlled by the `VITE_VARIANT` environment variable or hostname resolution:
1. **`full` (Default)**: Complete geopolitical, military, conflict, and infrastructure intelligence (`worldmonitor.app`).
   - *Evidence*: `src/config/variants/`, `package.json` (`"build:full"`), `AGENTS.md`.
   - *Status*: Implemented and Active.
2. **`tech`**: Startup, AI/ML, cloud, and cybersecurity focus (`tech.worldmonitor.app`).
   - *Evidence*: `package.json` (`"dev:tech"`), `AGENTS.md`, `README.md`.
   - *Status*: Implemented and Active.
3. **`finance`**: Markets, central banks, trading, and commodities focus (`finance.worldmonitor.app`).
   - *Evidence*: `package.json` (`"dev:finance"`), `AGENTS.md`, `README.md`.
   - *Status*: Implemented and Active.
4. **`commodity`**: Commodity markets, mining, and energy focus (`commodity.worldmonitor.app`).
   - *Evidence*: `package.json` (`"dev:commodity"`), `AGENTS.md`, `README.md`.
   - *Status*: Implemented and Active.
5. **`happy`**: Positive news and constructive global signals (`happy.worldmonitor.app`).
   - *Evidence*: `package.json` (`"dev:happy"`), `AGENTS.md`, `README.md`.
   - *Status*: Implemented and Active.
6. **`energy`**: Energy security, chokepoints, oil/gas, and disruption timelines (`energy.worldmonitor.app`).
   - *Evidence*: `package.json` (`"dev:energy"`), `AGENTS.md`, `README.md`.
   - *Status*: Implemented and Active.

---

## 2. Primary Application Entry Points

- **Browser SPA Main Entry**: `index.html` mounts `<script type="module" src="/src/main.ts">`, initializing Sentry, theme, fetch patches, and triggering `App.init()`.
  - *Evidence*: `index.html`, `src/main.ts`, `src/App.ts`.
  - *Status*: Implemented and Active.
- **Live Map Embed Entry**: `public/embed.html` -> `/src/embed-main.ts` rendering embeddable map widgets with restricted CSP and no-store headers.
  - *Evidence*: `public/embed.html`, `vercel.json` (`/embed`).
  - *Status*: Implemented and Active.
- **Live Channels Entry**: `public/live-channels.html` -> `/src/live-channels-main.ts` providing grid channel management.
  - *Evidence*: `public/live-channels.html`.
  - *Status*: Implemented and Active.
- **Desktop Settings Window**: `public/settings.html` -> `/src/settings-main.ts` managing desktop API keys, Ollama endpoints, and log diagnostics.
  - *Evidence*: `public/settings.html`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **MCP Grant Consent Entry**: `public/mcp-grant.html` -> `/src/mcp-grant-main.ts` handling OAuth consent flows for MCP clients.
  - *Evidence*: `public/mcp-grant.html`, `vercel.json`.
  - *Status*: Implemented and Active.
- **Edge API Gateway Entry Points**: Generated per-domain handlers under `api/<domain>/v1/[rpc].ts` created via `createDomainGateway` (`server/gateway.ts`).
  - *Evidence*: `server/gateway.ts`, `server/router.ts`, `api/`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Desktop Main Process**: `src-tauri/src/main.rs` executing Tauri Rust shell and spawning Node.js sidecar `src-tauri/sidecar/local-api-server.mjs`.
  - *Evidence*: `src-tauri/src/main.rs`, `src-tauri/sidecar/local-api-server.mjs`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Railway AIS Relay Entry**: `scripts/ais-relay.cjs` managing WebSocket proxy, OREF polling, and seed loops.
  - *Evidence*: `scripts/ais-relay.cjs`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.

---

## 3. Frontend Frameworks and Build Systems

- **Component Architecture**: Vanilla TypeScript component model (no React in main SPA). All 107 panel components extend the `Panel` base class (`src/components/Panel.ts`) with 150ms debounced rendering and event delegation.
  - *Evidence*: `src/components/Panel.ts`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Preact Integration**: Preact `10.25.4` is used selectively for specific lightweight UI widgets (e.g. `@deck.gl/widgets`, `@base-org/account`).
  - *Evidence*: `package.json` (`"preact": "^10.25.4"`), `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Build System**: Vite `6.0.7` configured in `vite.config.ts` with `@tailwindcss/vite` / Tailwind CSS v4 (`@import "tailwindcss";` in `src/index.css`).
  - *Evidence*: `vite.config.ts`, `package.json`, `src/index.css`.
  - *Status*: Implemented and Active.
- **Type Checking**: TypeScript `5.7.2` with strict mode enabled (`tsc --noEmit`). Separate project references for API (`tsconfig.api.json`) and DOM tests (`tsconfig.dom-tests.json`).
  - *Evidence*: `tsconfig.json`, `tsconfig.api.json`, `tsconfig.dom-tests.json`, `package.json`.
  - *Status*: Implemented and Active.
- **Bundling & Optimization**: `esbuild` `0.28.1` for fast CommonJS bundling of server code into `dist/server.cjs` and edge handlers.
  - *Evidence*: `package.json`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **PWA Integration**: `vite-plugin-pwa` `1.2.0` generating Workbox service workers with NetworkOnly navigation fallback and one-time nuke on asset 404.
  - *Evidence*: `package.json`, `index.html`, `CHANGELOG.md`.
  - *Status*: Implemented and Active.
- **Linting & Code Style**: Biome `2.4.7` (`biome.json`), `markdownlint-cli2` for documentation, and custom boundary/safe-html lint scripts (`scripts/lint-boundaries.mjs`, `scripts/enforce-safe-html.mjs`).
  - *Evidence*: `biome.json`, `package.json`.
  - *Status*: Implemented and Active.

---

## 4. Backend, Edge, Relay, Worker, and Scheduled Services

- **Vercel Edge Functions (`api/`)**: Deployed on Vercel's edge runtime. Functions are self-contained JS bundles produced via esbuild.
  - *Evidence*: `api/`, `tests/edge-functions.test.mjs`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Gateway Pipeline (`server/gateway.ts`)**: Pipeline enforcing CORS, rate limiting (Upstash sliding window), API key validation, route matching, POST-to-GET conversion, ETag (FNV-1a) 304 revalidation, and error boundaries.
  - *Evidence*: `server/gateway.ts`, `server/router.ts`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Edge Middleware (`middleware.ts`)**: Vercel Edge middleware filtering automated crawler traffic, detecting site variants from hostname, and serving social preview OG tags.
  - *Evidence*: `middleware.ts`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Railway AIS Relay (`scripts/ais-relay.cjs`)**: Dockerized Node.js service running WebSocket proxy for live ship tracking, OREF Israel Sirens polling, RSS proxying, and continuous seed loops.
  - *Evidence*: `scripts/ais-relay.cjs`, `docker/Dockerfile`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Consumer Prices Collector (`consumer-prices-core/`)**: Playwright scrapers harvesting basket inflation data per country and publishing directly to Redis.
  - *Evidence*: `consumer-prices-core/Dockerfile`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Convex BaaS (`convex/`)**: Reactive backend managing Clerk authentication, user entitlements, Dodo Payments webhooks, email broadcasts, contact/waitlist forms, and vector memory.
  - *Evidence*: `convex/schema.ts`, `package.json`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Browser Web Workers**:
  - `src/workers/analysis.worker.ts`: News clustering using Jaccard similarity (>0.6) and cross-domain correlation.
  - `src/workers/ml.worker.ts`: In-browser ONNX inference via `@xenova/transformers` (MiniLM-L6 embeddings, sentiment, NER).
  - `src/workers/vector-db.ts`: IndexedDB-backed vector database for semantic search.
  - *Evidence*: `src/workers/`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.

---

## 5. Map Renderers and Geospatial Abstractions

- **Dual Map Architecture**:
  - **`DeckGLMap` (`src/components/DeckGLMap.ts`)**: WebGL rendering via deck.gl `9.2.11` and MapLibre GL `5.16.0`. Renders 56 layer types including ScatterplotLayer, GeoJsonLayer, PathLayer, IconLayer, PolygonLayer, ArcLayer, HeatmapLayer, and H3HexagonLayer (`h3-js` v4.4.0). Uses Supercluster (`8.0.1`) for marker clustering and PMTiles (`4.4.0`) for self-hosted basemaps on Cloudflare R2 (`maps.worldmonitor.app`).
  - **`GlobeMap` (`src/components/GlobeMap.ts`)**: 3D globe visualization via `globe.gl` (`2.45.0`) and Three.js (`0.183.2`), featuring Earth/Cosmos texture presets and atmosphere shaders.
  - *Evidence*: `src/components/DeckGLMap.ts`, `src/components/GlobeMap.ts`, `package.json`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Map Layer Definitions (`src/config/map-layer-definitions.ts`)**: Central registry specifying flat/globe renderer compatibility, premium entitlement status, variant filtering, and i18n keys for all 56 map layers.
  - *Evidence*: `src/config/map-layer-definitions.ts`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Geospatial Boundary Overrides**: Country geometry loaded from `public/data/countries.geojson` with Natural Earth high-res boundary overrides hosted on R2 (`maps.worldmonitor.app`).
  - *Evidence*: `CONTRIBUTING.md`, `CHANGELOG.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.

---

## 6. Layer Registries, Panels, Workspaces, and Feature Variants

- **Panel Registry (`src/config/panels.ts`)**: Registers 181 top-level component files and 107 `Panel` subclasses across `FINANCE_PANELS`, `FULL_PANELS`, `TECH_PANELS`, `COMMODITY_PANELS`, `HAPPY_PANELS`, and `ENERGY_PANELS`.
  - *Evidence*: `src/config/panels.ts`, `src/components/`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Layout Manager (`src/app/panel-layout.ts`)**: `LayoutManager` handles resizable row/col spans, tab creation (capped per plan), drag-and-drop ordering, and viewport-conditional lazy panel loading.
  - *Evidence*: `src/app/panel-layout.ts`, `CHANGELOG.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Route Explorer (`src/components/RouteExplorerModal.ts`)**: Standalone full-screen trade and maritime route planning modal accessible via CMD+K, featuring Current/Alternatives/Land/Impact analysis tabs.
  - *Evidence*: `CHANGELOG.md`, `README.md`.
  - *Status*: Implemented and Active.

---

## 7. API and Contract Surfaces

- **sebuf RPC Framework (v0.11.1)**: Proto-first HTTP RPC framework defined in `proto/worldmonitor/<domain>/v1/`. Stubs generated in `src/generated/client/` and `src/generated/server/`.
  - *Evidence*: `proto/`, `Makefile` (`SEBUF_VERSION = v0.11.1`), `src/generated/`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **OpenAPI Documentation (`docs/api/`)**: Per-service OpenAPI v3.1 YAML/JSON specs and a unified bundle `docs/api/worldmonitor.openapi.yaml` covering 190 RPC operations.
  - *Evidence*: `docs/api/worldmonitor.openapi.yaml`, `package.json` (`"build:openapi"`), `ARCHITECTURE.md`, `CONTRIBUTING.md`.
  - *Status*: Implemented and Active.
- **MCP (Model Context Protocol) Server**:
  - Deployed at `/mcp` (`api/mcp.ts`) implementing Streamable HTTP transport (JSON-RPC 2.0 via POST, SSE via GET) and Discovery (`GET` returning markdown guide or JSON card).
  - Server Discovery Card served at `/.well-known/mcp/server-card.json` exposing 59 tools.
  - *Evidence*: `api/mcp.ts`, `public/.well-known/mcp/server-card.json`, `vercel.json`, `CONCEPTS.md`.
  - *Status*: Implemented and Active.
- **Operational Non-Proto Endpoints**: Listed in `api/api-route-exceptions.json` (e.g. `/api/bootstrap`, `/api/health`, `/api/mcp`, `/api/create-checkout`, `/api/customer-portal`, `/api/user-prefs`). Enforced by `npm run lint:api-contract`.
  - *Evidence*: `api/api-route-exceptions.json`, `package.json`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.

---

## 8. Caching, Persistence, Last-Known-Good, and Offline Mechanisms

- **Cache Tiers**:
  - `fast` (300s): Live event streams, flight positions.
  - `medium` (600s): Stock quotes, market analysis.
  - `slow` (1800s): ACLED/UCDP conflict events, cyber threats.
  - `static` (7200s): Humanitarian summaries, ETF flows.
  - `daily` (86400s): Critical minerals, macro data.
  - `no-store` (0s): Vessel snapshots, live aircraft tracking.
  - *Evidence*: `server/gateway.ts`, `server/_shared/redis.ts`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Coalesced Redis Caching**: `cachedFetchJson()` in `server/_shared/redis.ts` uses Upstash Redis and lock coalescing to prevent cache stampedes on concurrent misses.
  - *Evidence*: `server/_shared/redis.ts`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Atomic Seed Publishing**: `atomicPublish()` in `scripts/_seed-utils.mjs` uses Redis SET NX locks, writes payload, and updates `seed-meta:<key>` with `{ fetchedAt, recordCount }`.
  - *Evidence*: `scripts/_seed-utils.mjs`, `api/health.js`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Bootstrap Hydration**: `/api/bootstrap` batch-reads Redis keys in fast/slow tiers. SPA fetches concurrently via `src/services/bootstrap.ts`.
  - *Evidence*: `api/bootstrap.js`, `src/services/bootstrap.ts`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Last-Known-Good (LKG) Fallback**: Client retains `Last-Good Digest` locally in IndexedDB/localStorage to render news during network or API degradation.
  - *Evidence*: `CONCEPTS.md`, `CHANGELOG.md`.
  - *Status*: Implemented and Active.

---

## 9. PWA and Desktop/Tauri Paths

- **Progressive Web App (PWA)**: PWA webmanifest and Workbox Service Worker (`sw.js`). Nuke key (`wm-sw-nuke`) purges stale caches on redeployment asset errors.
  - *Evidence*: `package.json`, `index.html`, `CHANGELOG.md`.
  - *Status*: Implemented and Active.
- **Tauri 2.x Shell**: Native desktop shell built in Rust (`src-tauri/src/main.rs`). Configured in `src-tauri/tauri.conf.json`, `tauri.tech.conf.json`, and `tauri.finance.conf.json`.
  - *Evidence*: `src-tauri/`, `package.json` (`"desktop:build:full"`), `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Node.js Local API Sidecar**: `src-tauri/sidecar/local-api-server.mjs` runs on a dynamic local port, loads edge function handlers, forces IPv4, and injects secrets.
  - *Evidence*: `src-tauri/sidecar/local-api-server.mjs`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Desktop Runtime Fetch Interceptor**: `installRuntimeFetchPatch()` in `src/services/runtime.ts` intercepts `/api/*` fetches on desktop, attaching a 5-minute bearer token (`LOCAL_API_TOKEN`) and routing through the sidecar.
  - *Evidence*: `src/services/runtime.ts`, `src/services/tauri-bridge.ts`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **OS Platform Keyring Vault**: Secrets stored in OS Keychain (macOS Keychain, Windows Credential Manager, Linux Secret Service) as a single JSON vault entry `secrets-vault`.
  - *Evidence*: `CHANGELOG.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.

---

## 10. Authentication, Permissions, Roles, Entitlements, and Feature Flags

- **Authentication Systems**:
  - **Clerk Authentication (`@clerk/clerk-js`)**: Handles user accounts and session tokens.
  - **Origin-Aware API Key Validation (`api/_api-key.js`, `api/_user-api-key.js`)**: Requires API keys for external/non-browser requests while exempting trusted browser origins.
  - **Anonymous Sessions (`api/_session.js`)**: HttpOnly signed cookies authorizing keyless browser visitors.
  - *Evidence*: `api/_api-key.js`, `api/_session.js`, `package.json`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Entitlements & Pricing Tiers**:
  - 5 Plans: Free (3 tabs), Pro ($39.99/mo, 10 tabs, 50 MCP calls/day), Pro Business ($49.99/mo, 25 tabs, 250 MCP calls/day, data export enabled), API plans, Enterprise.
  - Payment processing via Dodo Payments (`dodopayments-checkout`, `@dodopayments/convex`).
  - *Evidence*: `CHANGELOG.md`, `CONCEPTS.md`, `convex/schema.ts`, `index.html`.
  - *Status*: Implemented and Active.
- **Feature Flags**: Evaluated by merging plan catalog defaults into reactive entitlement snapshots (`CONCEPTS.md`).
  - *Evidence*: `CONCEPTS.md`.
  - *Status*: Implemented and Active.

---

## 11. Localization and RTL Foundations

- **i18n Core**: Powered by `i18next` (`25.8.10`) and `i18next-browser-languagedetector` (`8.2.1`).
  - *Evidence*: `package.json`, `src/main.ts`, `AGENTS.md`.
  - *Status*: Implemented and Active.
- **26 Supported Locales**: Translation files located in `src/locales/` (en, fr, de, es, it, pl, pt, nl, sv, ru, ar, zh, ja, el, etc.). Key parity enforced by `npm run sync:locales:check`.
  - *Evidence*: `src/locales/`, `package.json`, `CONTRIBUTING.md`, `CHANGELOG.md`.
  - *Status*: Implemented and Active.
- **RTL & Typographic Foundations**: Full Right-to-Left (`dir="rtl"`) support for Arabic (`ar`) with dedicated RTL CSS rules. Fonts loaded via `@fontsource/tajawal` and `@fontsource/nunito`.
  - *Evidence*: `package.json`, `src/styles/`, `CHANGELOG.md`, `README.md`.
  - *Status*: Implemented and Active.

---

## 12. AI or ML Providers and Fallbacks

- **Server-Side Gemini AI**: `@google/genai` (`2.4.0`) used in server handlers for news summarization, intelligence briefs, and insights via `GEMINI_API_KEY`.
  - *Evidence*: `package.json`, `metadata.json`, `.env.example`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **4-Tier Summarization Fallback Chain**:
  1. **Local LLM**: Ollama / LM Studio (OpenAI-compatible `/v1/chat/completions` at `http://localhost:11434`).
  2. **Groq API**: Cloud LLM inference.
  3. **OpenRouter API**: Free/auto-routed cloud LLM fallback.
  4. **Transformers.js / ONNX**: In-browser T5-small execution via `@xenova/transformers` and `onnxruntime-web`.
  - *Evidence*: `CHANGELOG.md`, `ARCHITECTURE.md`, `README.md`.
  - *Status*: Implemented and Active.

---

## 13. Test Categories and Quality Gates

- **Unit & Integration Suite**:
  - `node:test` runner executing `tests/*.test.mjs`, `tests/*.test.mts`, `api/*.test.mjs`, `src-tauri/sidecar/*.test.mjs`.
  - *Evidence*: `package.json` (`"test:data"`, `"test:sidecar"`), `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **End-to-End Suite**:
  - Playwright (`1.52.0`) running E2E specs in `e2e/*.spec.ts`.
  - *Evidence*: `package.json` (`"test:e2e"`), `playwright.config.ts`, `AGENTS.md`.
  - *Status*: Implemented and Active.
- **Visual Regression**:
  - Playwright golden screenshot comparison per variant and zoom level (`npm run test:e2e:visual`).
  - *Evidence*: `package.json` (`"test:e2e:visual"`), `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Contract & Boundary Lints**:
  - `tests/edge-functions.test.mjs` verifying edge functions are self-contained JS.
  - `scripts/enforce-sebuf-api-contract.mjs` validating RPC annotations.
  - `scripts/lint-boundaries.mjs` checking layer import direction.
  - *Evidence*: `package.json`, `AGENTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.
- **Pre-Push Hook (`.husky/pre-push`)**:
  - Two-tiered gate: state-dependent always-run checks (secret dumps, PR state, lockfile sync) + tree-dependent diff-scoped checks (typecheck, boundary lints, edge esbuild, tests) backed by a green-tree cache (`$GIT_DIR/wm-prepush-green`).
  - *Evidence*: `AGENTS.md`, `CONCEPTS.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.

---

## 14. Deployment Topologies

1. **Vercel (Web SPA & Edge Functions)**: Static SPA hosting, Vercel Edge Functions API gateway, and edge middleware.
   - *Evidence*: `vercel.json`, `ARCHITECTURE.md`.
   - *Status*: Implemented and Active.
2. **Cloudflare Worker (CORS Preflight)**: Edge CORS preflight worker for `api.worldmonitor.app`.
   - *Evidence*: `workers/api-cors-preflight/wrangler.toml`, `ARCHITECTURE.md`.
   - *Status*: Implemented and Active.
3. **Railway (Docker Containers)**:
   - `ais-relay`: WebSocket proxy and continuous seed loops (`scripts/ais-relay.cjs`).
   - `consumer-prices-core`: Containerized Playwright price scrapers.
   - `umami`: Self-hosted analytics collector (`Dockerfile.umami`).
   - *Evidence*: `docker/Dockerfile`, `docker/Dockerfile.umami`, `consumer-prices-core/Dockerfile`, `ARCHITECTURE.md`.
   - *Status*: Implemented and Active.
4. **Upstash Redis (Cache Layer)**: Cloud Redis instance for multi-instance cache and seed metadata.
   - *Evidence*: `server/_shared/redis.ts`, `ARCHITECTURE.md`.
   - *Status*: Implemented and Active.
5. **Convex Cloud (BaaS)**: Managed database for Clerk user state, Dodo billing, and vector memory.
   - *Evidence*: `convex/schema.ts`, `package.json`, `ARCHITECTURE.md`.
   - *Status*: Implemented and Active.
6. **Multi-Platform Desktop (Tauri)**: GitHub Actions (`build-desktop.yml`) building macOS (ARM64/x64), Windows (x64), and Linux (AppImage) binaries.
   - *Evidence*: `.github/workflows/build-desktop.yml`, `src-tauri/`, `ARCHITECTURE.md`.
   - *Status*: Implemented and Active.
7. **GHCR Container Registry**: Multi-arch Docker images pushed to GitHub Container Registry.
   - *Evidence*: `.github/workflows/docker-publish.yml`, `docker/Dockerfile`, `ARCHITECTURE.md`.
   - *Status*: Implemented and Active.
8. **Package Registries**: OIDC trusted publishing to npm (`cli/`), PyPI (`sdk/python/`), RubyGems (`sdk/ruby/`), and Go proxy (`sdk/go/`).
   - *Evidence*: `.github/workflows/publish-*.yml`, `package.json`, `ARCHITECTURE.md`.
   - *Status*: Implemented and Active.

---

## 15. Licensing and Attribution Obligations

- **Source License**: **AGPL-3.0-only** (`package.json`, `README.md`, `LICENSE`, `CONCEPTS.md`). Commercial use permitted under AGPL copyleft and source disclosure terms.
  - *Evidence*: `package.json` (`"license": "AGPL-3.0-only"`), `README.md`, `LICENSE`.
  - *Status*: Implemented and Active.
- **Upstream Data Attributions**:
  - Flight ADS-B data courtesy of Wingbits.
  - Umami analytics session-data upsert patch maintained under `docker/umami/session-data-upsert.patch`.
  - OpenSky Network, ACLED, UCDP, NASA FIRMS, USGS, FRED, IMF, BIS, OFAC, ECMWF, IAEA, WHO, TeleGeography, Natural Earth attributions.
  - *Evidence*: `.gitignore`, `README.md`, `ARCHITECTURE.md`.
  - *Status*: Implemented and Active.

---

## 16. Claims Still Requiring Runtime Verification

The following operational capabilities and integration points cannot be fully validated by static source analysis alone and require live runtime verification:

1. **Live Railway AIS Relay WebSocket Stream**: Live WebSocket throughput, latency, and reconnection behavior under peak vessel density.
2. **Upstash Redis Cache Miss Coalescing & Hit Ratios**: Real-time performance of `cachedFetchJson()` and Redis lock acquisition under heavy concurrent traffic.
3. **Live Convex BaaS Vector Memory Search**: Vector similarity search latency and Dodo Payments webhook event delivery under live load.
4. **Wingbits / OpenSky API Rate-Limit Fallback**: Failover transition timing when primary Wingbits endpoints return HTTP 429 or 5xx.
5. **Desktop Local Ollama Endpoint Auto-Discovery**: Cross-platform behavior when discovering local LLM models on diverse user hardware.
6. **Cloudflare Apex-to-www Redirect Exemption Rules**: Real-time evaluation of Cloudflare Dynamic Redirect rules for `/mcp` and `/.well-known/` paths without triggering 301 redirects.
