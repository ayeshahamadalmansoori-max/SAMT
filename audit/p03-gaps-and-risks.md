# P03 Gaps and Risks

## High-Priority Gaps

1. Static extraction cannot prove runtime reachability or provider health.
2. Registrations and callers require manual symbol-level tracing.
3. Feature-flag defaults and entitlements require inspection of variant and authorization logic.
4. Layer definitions require renderer, source, permission, and UI availability verification.
5. Documentation, fixtures, examples, generated clients, and dead code may create false positives.
6. Deprecation keywords may refer to data or API versions rather than complete capability retirement.
7. Build and tests were not executed by this work unit.

## Required Follow-Up

- Review p03-capability-inventory.csv.
- Review p03-feature-flag-and-entitlement-matrix.csv.
- Review p03-deprecated-and-sunset.csv.
- Sample each capability family back to source files and registrations.
- Run the local quality gate before closing the foundation phase.
