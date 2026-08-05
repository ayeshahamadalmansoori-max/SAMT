# P05 Arabic Terminology and Localization Audit

## Metadata

- Timestamp: 2026-08-05T09:03:35.1056146+04:00
- Branch: samt/transformation
- Commit: 58e694e6866cdc25c0b4f8ed8ac0070e443a399b
- Working tree clean at start: True
- Method: controlled glossary comparison and deterministic static repository scan

## Controlled Reference

- Terminology rows: 137
- Status labels: 40
- UI labels: 39
- Domain labels: 15
- Guidance rules: 12

## Repository Localization Inventory

- Locale candidate files: 66
- Flattened English locale values: 3176
- Flattened Arabic locale values: 3248

## Exact Glossary Coverage

- Preferred Arabic found: 25
- Alternate or avoided Arabic found: 9
- English found without preferred Arabic: 19
- No exact locale match found: 163

Exact string matching is conservative. Missing an exact match does not prove that a concept is absent; contextual and key-level review remains required.

## Risks

- Untranslated and duplicate-label risk rows: 838
- Mixed/LTR direction reference rows: 17
- Formatting checks: 7

## Audit Boundary

No locale file, user-facing string, application component, or runtime configuration was modified.
No machine translation was introduced.
No build, visual, accessibility, screen-reader, or RTL runtime test was executed.

## Required Manual Review

- Approve one Arabic term per concept across navigation, tooltips, alerts, briefs, and reports.
- Review every alternate or avoided Arabic match.
- Isolate URLs, source IDs, airport codes, callsigns, registrations, vessel identifiers, stock tickers, coordinates, and technical identifiers.
- Verify Arabic date, time, number, plural, and timezone behavior.
- Preserve original source names and evidence text where required.
- Obtain specialist review for military, legal, health, and financial terminology.

## Next Work Unit

After P05 review, commit and phase backup, proceed to P06 RTL foundation.
