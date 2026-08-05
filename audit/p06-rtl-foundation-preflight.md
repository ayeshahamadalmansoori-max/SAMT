# P06 RTL Foundation Preflight

## Metadata

- Timestamp: 2026-08-05T09:34:38.8729895+04:00
- Branch: samt/transformation
- Commit: 5e46e85d52fdb56b0d469cb47caaa84245eb3f2a
- Working tree clean at start: True
- Method: deterministic local repository inspection

## Purpose

Identify the exact application root, layout, style, localization, and test files for a bounded P06 implementation.
This preflight does not modify application code.

## Counts

- Root/style/localization candidates: 88
- Files with physical or logical direction evidence: 12
- Existing test candidates: 1496

## Relevant Dependencies

- i18next
- i18next-browser-languagedetector

## Relevant Package Scripts

- build
- build:agent-skills
- build:blog
- build:commodity
- build:crawlable-corpus
- build:desktop
- build:energy
- build:finance
- build:full
- build:happy
- build:openapi
- build:pro
- build:sidecar-sebuf
- build:sitemap
- build:sitemap:check
- build:tech
- desktop:build:finance
- desktop:build:full
- desktop:build:tech
- lint
- lint:api-contract
- lint:boundaries
- lint:fix
- lint:md
- lint:mintlify-slugs
- lint:premium-fetch
- lint:public-docs
- lint:rate-limit-policies
- lint:safe-html
- lint:unicode
- lint:unicode:staged
- prebuild
- prebuild:blog
- prebuild:commodity
- prebuild:energy
- prebuild:finance
- prebuild:full
- prebuild:happy
- prebuild:pro
- prebuild:tech
- test:convex
- test:convex:watch
- test:data
- test:dom
- test:e2e
- test:e2e:commodity
- test:e2e:energy
- test:e2e:finance
- test:e2e:full
- test:e2e:happy
- test:e2e:mcp-grant
- test:e2e:news-budget
- test:e2e:runtime
- test:e2e:tech
- test:e2e:variant-smoke
- test:e2e:variant-smoke:commodity
- test:e2e:variant-smoke:energy
- test:e2e:variant-smoke:finance
- test:e2e:variant-smoke:full
- test:e2e:variant-smoke:happy
- test:e2e:variant-smoke:tech
- test:e2e:visual
- test:e2e:visual:full
- test:e2e:visual:tech
- test:e2e:visual:update
- test:e2e:visual:update:full
- test:e2e:visual:update:tech
- test:feeds
- test:feeds:ci
- test:resilience-validation-smoke
- test:sidecar
- typecheck
- typecheck:all
- typecheck:api
- typecheck:dom-tests
- worktree:bootstrap:test-only

## Highest Physical-Direction Risk Files

- src/styles/main.css — physical=395, logical=3
- src/styles/panels.css — physical=91, logical=2
- src/styles/rtl-overrides.css — physical=47, logical=0
- src/styles/country-deep-dive.css — physical=29, logical=0
- public/pro/assets/index-eYnecI2g.css — physical=19, logical=59
- src/styles/settings-window.css — physical=18, logical=0
- blog-site/src/styles/global.css — physical=11, logical=0
- src/styles/route-explorer.css — physical=9, logical=0
- src/styles/happy-theme.css — physical=7, logical=0
- src/styles/embed.css — physical=3, logical=0
- src/styles/header.css — physical=2, logical=0
- src/styles/supply-chain-panel.css — physical=1, logical=0

## P06 Implementation Boundary

The implementation should remain limited to:

- Arabic application-root language and RTL direction behavior.
- Reusable direction and bidirectional-isolation primitives.
- Logical layout foundations where safe.
- A bounded set of representative components.
- RTL and mixed-direction automated tests.

Do not redesign information architecture, replace the map shell, remove capabilities, or translate every interface string in P06.

## Required Next Action

Review the three generated CSV files and identify the actual production root, global styles, representative components, and test framework before applying the P06 code patch.
