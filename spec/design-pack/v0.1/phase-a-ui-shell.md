# Phase A Implementation Brief — Polished UI Shell (Mock Data Only)

## Objective
Implement a polished, modern frontend shell for Purview Workbench using routed pages and deterministic mock data, while preserving public-first behavior and protected-action auth gating.

## Must implement
1. **Routed public shell**
   - Implement/refresh routes defined in `page-map.md`.
   - Ensure primary navigation is always available without sign-in.

2. **Visual/layout improvements**
   - Apply app shell structure from `layout-system.md`.
   - Upgrade spacing, typography, and component consistency based on `design-system.md`.
   - Add light/dark theme toggle and persist user preference.

3. **Public libraries and docs pages**
   - Build SIT Library, DLP Library, Rule Packs info, and Help pages with mock data.
   - Add searchable/filterable list experience for SIT/DLP libraries.

4. **Test Console UX shell**
   - Build the Test Console interface for input + result visualization.
   - Keep execution mock-only; no real backend worker integration.
   - Simulate queued/running/completed/failed states.

5. **Protected-action gate**
   - Create a reusable protected-action gating component/hook.
   - Trigger auth only when protected actions are attempted.
   - Preserve return-to-action context after sign-in.

6. **Consent-aware protected UI**
   - For authenticated users without consent, show consent-required state and route to Settings/Tenant Connection.

7. **Settings shell**
   - Implement protected Settings/Tenant/Consent pages as UX shell with placeholder status data.

## Must not implement
- No expansion of backend job execution logic.
- No PowerShell/cmdlet execution integration.
- No real blob upload/SAS flows.
- No full SIT editor or DLP builder functionality.
- No architecture changes that conflict with build-pack v0.1.

## Data constraints
- Use deterministic mock fixtures only.
- Keep fixture shape aligned with `mock-data.md`.
- No timestamps/random values in mock generators.

## UX acceptance checklist
- Public pages fully browseable anonymously.
- Protected actions trigger auth prompt only when clicked.
- Post-auth user returns to intended page/action context.
- Consent-required state clearly blocks protected actions with remediation path.
- Loading/empty/error/auth/consent/job states implemented consistently.
- Layout quality is visibly polished and cohesive across pages.

## Engineering checklist for Codex
- Reuse existing frontend structure; avoid rewrites.
- Add/extend shared UI primitives instead of one-off components.
- Keep diffs reviewable and route-by-route.
- Add/update frontend tests for:
  - anonymous route access
  - protected action gating
  - consent-required behavior
  - theme toggle persistence
- Keep all new behavior inside current public-first auth model.
