# P02 - OSINT Source Audit

## Current phase

Foundation audit. No user-interface or runtime implementation changes are permitted in this work unit.

## Objective

Inspect the checked-out World Monitor repository and produce an evidence-based inventory of OSINT sources, feeds, channels, APIs, WebSockets, datasets, scrapers, seeders, pollers, relays, credentials, licensing indicators, freshness logic, health states, and fallbacks.

The checked-out repository code, registrations, configuration, contracts, and current tests are the implementation source of truth.

## Required inputs to inspect first

Inspect, where present:

- `audit/repository-tree.txt`
- `audit/s04-architecture-summary.json`
- `audit/s04-key-files.csv`
- `audit/p01-repository-architecture-audit.md`
- `audit/p01-unresolved-questions.md`
- `audit/p01-evidence-index.csv`
- Source registries and provider configuration
- RSS, Atom, Telegram, API, WebSocket, scraper, static-data, seeder, poller, and relay code
- Environment-variable declarations and examples
- Server/client credential boundaries
- Retry, timeout, quota, cache, fallback, and health logic
- Source-related tests, fixtures, and mocks
- Licensing, attribution, provider terms, and redistribution notes
- Feature flags, entitlements, and disabled or deprecated source paths
- Map layers, panels, alerts, reports, or search surfaces that consume each source

## Source-of-truth rules

1. Do not mark a source active merely because:
   - An endpoint or URL appears in the repository
   - A package is installed
   - A README lists the source
   - A fixture, example, mock, or test mentions it
   - A generated client exists without a verified caller
   - A connector is disabled by a feature flag
   - Required credentials are absent
   - The provider cannot currently be reached
2. Verify registrations, imports, callers, feature state, and user-facing consumption paths.
3. Record credential names only. Never read, print, copy, infer, or expose secret values.
4. Distinguish runtime availability from static implementation evidence.
5. Treat provider failures and missing credentials as degraded or unavailable states, not as zero data.
6. Do not replace missing sources with fabricated, simulated, or static operational data.

## Required source categories

Audit and classify:

- API providers
- RSS and Atom feeds
- WebSocket providers
- Telegram channels
- Scrapers
- Static datasets
- Seeders
- Pollers
- Relay services
- Manual registries
- Fallback providers
- Credential-dependent connectors
- Restricted, premium, experimental, disabled, deprecated, and sunset sources

## Required status values

Use only evidence-supported states:

- Implemented and active
- Implemented but degraded
- Partially implemented
- Experimental
- Credential required
- Permission or entitlement restricted
- Agreement or licence required
- Disabled by feature flag
- Simulated
- Deprecated
- Sunset
- Documented only
- Planned
- Currently unavailable
- Requires runtime verification

## Required source record fields

For every discovered source or source family, record as much as the repository supports:

- `sourceId`
- `nameOriginal`
- `nameArTarget`
- `publisher`
- `domainCodes`
- `sourceCategory`
- `geographicCoverage`
- `languages`
- `collectionMethod`
- `authentication`
- `environmentVariable`
- `licence`
- `credibilityTier`
- `stateAffiliation`
- `biasRisk`
- `expectedRefresh`
- `freshnessSla`
- `healthLogic`
- `fallbackSourceId`
- `surfaces`
- `dataNature`
- `limitations`
- `legalReviewStatus`
- `status`
- `sourceFiles`
- `registrations`
- `callers`
- `tests`
- `runtimeVerificationRequired`

When a field is not supported by repository evidence, use `unknown` or `requires review`. Do not infer unsupported values.

## Required outputs

Create only these audit files:

1. `audit/p02-osint-source-audit.md`
2. `audit/p02-source-inventory.csv`
3. `audit/p02-credential-name-matrix.csv`
4. `audit/p02-source-gaps-and-risks.md`
5. `audit/p02-evidence-index.csv`

### `p02-source-inventory.csv` minimum columns

- `sourceId`
- `nameOriginal`
- `domainCodes`
- `collectionMethod`
- `authentication`
- `environmentVariable`
- `licence`
- `status`
- `dataNature`
- `fallbackSourceId`
- `surfaces`
- `sourceFiles`
- `registrations`
- `limitations`
- `runtimeVerificationRequired`

### `p02-credential-name-matrix.csv` minimum columns

- `environmentVariable`
- `serverOrClientBoundary`
- `requiredOrOptional`
- `affectedSourceOrCapability`
- `declaredIn`
- `referencedBy`
- `missingBehavior`
- `notes`

Never include credential values.

### `p02-evidence-index.csv` minimum columns

- `area`
- `claim`
- `status`
- `filePath`
- `symbolOrSection`
- `verificationMethod`
- `limitation`

## Prohibited changes

- Do not modify application code.
- Do not alter user-facing UI.
- Do not add Arabic localization yet.
- Do not add, remove, enable, disable, or replace sources.
- Do not modify credentials, `.env` files, secret stores, or provider settings.
- Do not call live providers unless explicitly authorized.
- Do not probe restricted or authenticated endpoints.
- Do not modify API, RPC, Protobuf, schema, or generated-client contracts.
- Do not reactivate deprecated or sunset connectors.
- Do not create fabricated source-health results.
- Do not claim runtime health without measured evidence.

## Required completion report

Return:

1. Completed objective
2. Files reviewed
3. Files added
4. Verified source architecture
5. Source counts by collection method and status
6. Credential-dependent sources
7. Degraded, disabled, deprecated, sunset, and unavailable sources
8. Licensing and legal-review gaps
9. Freshness, health, cache, and fallback observations
10. Claims requiring runtime verification
11. Commands or tests executed
12. Build and test status
13. Security and privacy observations
14. Risks and limitations
15. Items not implemented
16. Rollback procedure
17. Local PowerShell verification commands
18. Recommended next work unit

Stop after P02. Do not proceed automatically to P03.
