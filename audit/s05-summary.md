# S05 Source and Capability Extraction

## Metadata

- Timestamp: 2026-08-04T14:52:15.8460862+04:00
- Branch: samt/transformation
- Commit: d106245d14e4f4ed9b730dda86e2fe1e2547363f
- Working tree clean at start: True

## Consolidated Counts

- Sources: 36
- Credential records: 26
- Capability records: 17
- Feature flags and entitlements: 162
- Deprecated and sunset evidence rows: 674

## Validation Boundary

This work unit consolidates P02 and P03 audit evidence into machine-readable outputs.
It does not claim runtime source availability, credential availability, renderer compatibility, entitlement activation, or successful provider access.

## Security

- Credential names only were processed.
- No secret values were read, printed, or stored.
- No application code, contracts, sources, flags, permissions, or UI files were modified.

## Outputs

- audit/s05-source-capability-inventory.json
- audit/s05-source-summary.csv
- audit/s05-capability-summary.csv
- audit/s05-credential-summary.csv
- audit/s05-feature-state-summary.csv
- audit/s05-summary.md
- audit/tools/S05-Local-Source-Capability-Extraction-WindowsPS51.ps1
