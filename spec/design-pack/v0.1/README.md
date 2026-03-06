# Design Pack v0.1 — Frontend UX Specification

## Purpose
This design pack defines the product UX, information architecture, and UI standards for the next frontend-focused phase of Purview Workbench. It is implementation-oriented and intentionally constrained to a polished public-first UI shell with mock data.

## Scope and constraints
- This pack aligns to `spec/build-pack/v0.1/build-pack-v0.1.md` and phases 0–2.
- Public-first browsing is the default user experience.
- Authentication is triggered only when a user attempts protected tenant actions.
- No expansion of backend execution, worker behavior, or PowerShell integration is included.
- No real tenant data integration is required in this phase; mock data only.

## Included documents
- `information-architecture.md`
- `page-map.md`
- `layout-system.md`
- `design-system.md`
- `user-flows.md`
- `screen-specs.md`
- `states-and-feedback.md`
- `mock-data.md`
- `phase-a-ui-shell.md`

## Implementation principles
1. **Public-first shell**: all primary browsing pages render without sign-in.
2. **Protected-action boundary**: gated actions prompt sign-in from action context.
3. **Return-to-context flow**: after sign-in, return users to the attempted action state.
4. **Consent awareness**: authenticated users without required consent see explicit consent-required UI.
5. **Mock-data determinism**: stable fixtures with deterministic ordering and no timestamps.
6. **Enterprise usability**: dense but readable layouts for policy, template, and test workflows.

## Assumptions
1. Existing route and auth scaffolding from phases 1–2 remains available and can be refactored without changing architecture.
2. A global frontend auth/session store can model three states: anonymous, authenticated, and pending protected action.
3. Protected actions can be represented in UI state with a serializable action descriptor (action id, route, payload preview).
4. Theme switching (light/dark) will be frontend-only in this phase, with persisted preference stored locally.
5. Public library data in this phase is fixture-backed and not sourced from backend persistence.
6. Test Console execution remains placeholder-only and must show queued/running/completed/failed mock states.

## Non-goals for this design pack
- Defining backend API changes beyond what already exists in the build-pack direction.
- Specifying PowerShell cmdlet execution logic.
- Designing full SIT editor and DLP builder execution workflows (future placeholder only).

## Success criteria for next implementation phase
- A polished routed UI shell exists with modern SaaS layout and theming.
- Public pages are useful and coherent without authentication.
- Protected action gating is consistent across all protected entry points.
- Screen-level loading/empty/error/auth/consent states are implemented with reusable components.
