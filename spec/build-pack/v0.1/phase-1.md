# Phase 1

Objective:
Implement sign-in, tenant onboarding, delegated admin-consent flow scaffolding, consent status visibility, and initial tenancy persistence while preserving the Phase 0 repo structure.

In scope:
- preserve the existing Phase 0 scaffold and build on top of it
- normalize API routes toward `/api/v1`
- add initial backend config for auth and tenant onboarding
- add initial database implementation for:
  - tenants
  - users
  - tenant_memberships
- add Alembic migration(s) for the above initial tables only
- add backend route skeletons for:
  - `GET /api/v1/me`
  - `GET /api/v1/tenants/me`
  - `GET /api/v1/tenants/me/consent-status`
  - `POST /api/v1/tenants/consent-complete`
- keep backend auth validation implementation minimal but structured, with clear boundaries for later real Entra JWT validation
- add frontend auth/onboarding shell for:
  - sign in
  - signed-in status
  - tenant connection status
  - admin consent start/completion flow
  - consent status banner/page
- add MSAL/browser auth scaffolding using environment variables only
- add shared contracts/types for auth and tenant onboarding
- add tests for the new Phase 1 routes and basic frontend auth/onboarding rendering
- update README/run instructions/environment variable examples

Implementation notes:
- preserve the vendor-owned multi-tenant Entra app model
- preserve delegated user auth
- do not add customer-side app registration
- do not add app-only auth
- do not add browser-side PowerShell
- do not implement real worker cmdlet execution in this phase
- do not implement full DLP/SIT editors in this phase
- keep the worker aligned to the eventual PowerShell/container model, but do not expand worker execution beyond placeholders unless required for shared contracts
- expand shared contracts rather than inventing disconnected per-app models
- prefer minimal, reviewable diffs

Recommended env/config placeholders:
- `VITE_ENTRA_CLIENT_ID`
- `VITE_ENTRA_AUTHORITY`
- `VITE_ENTRA_REDIRECT_URI`
- `VITE_API_AUDIENCE`
- `API_ENTRA_CLIENT_ID`
- `API_ENTRA_TENANT_MODE=multi-tenant`
- `API_ALLOWED_AUDIENCE`
- `API_DATABASE_URL`
- `API_ADMIN_CONSENT_REDIRECT_URI`

Acceptance criteria:
- frontend has a clear sign-in/onboarding/consent status flow scaffold
- backend exposes versioned `/api/v1` auth/tenant endpoints
- initial tenant/user tables exist via Alembic migration
- the repo still matches the Phase 0 architecture shape
- no later-phase product features are implemented
- tests/lint/typecheck run cleanly or any failures are clearly explained

Out of scope:
- real `Connect-ExchangeOnline` / `Connect-IPPSSession` execution
- real DLP/SIT authoring
- rule pack parsing beyond current placeholders
- community library
- reporting/tuning
- advanced JWT validation if it would require architectural guessing; structure the code for it instead
