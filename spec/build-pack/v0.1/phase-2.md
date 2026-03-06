# Phase 2

Objective:
Refactor the application from an auth-centric shell into a public-first web app, while introducing protected-action gating for tenant-scoped operations such as file upload, Test-TextExtraction, Test-DataClassification, tenant sync, and future dictionary/rule-pack operations.

This phase supersedes any assumption that users must authenticate to access the general app shell. Authentication should only be initiated when the user attempts a protected tenant action.

## In scope

### Public-first application shell
- make the main app usable without sign-in
- add a public landing/dashboard shell
- add public navigation for:
  - home/dashboard
  - SIT library/templates (public placeholder view)
  - DLP library/templates (public placeholder view)
  - rule packs (public informational shell)
  - help/docs/about
- preserve the existing Phase 1 onboarding/auth pieces, but move them behind protected actions or explicit sign-in controls

### Protected action boundary
- introduce a clear protected-action gate in the frontend
- anonymous users must be able to browse public pages without authentication
- authentication should only be triggered when the user attempts:
  - upload a file for Test-TextExtraction
  - run Test-DataClassification
  - access tenant consent status
  - sync tenant policies/rules/dictionaries
  - push/import/export tenant-connected artifacts
- if a protected action is attempted while signed out:
  - show a clear prompt/modal/banner
  - allow user to start sign-in from that point
  - after sign-in, return user to the requested action context

### Public vs protected frontend behavior
- public pages must not automatically call protected API endpoints
- tenant onboarding UI should only appear:
  - after explicit sign-in, or
  - when the user attempts a protected tenant feature
- add a lightweight global auth state model that supports:
  - anonymous session
  - authenticated session
  - protected-action pending state

### Auth storage cleanup
- remove reliance on persisted placeholder access tokens in localStorage
- keep any dev-mode auth skeleton minimal and clearly temporary
- if local storage is used at all, it must not hold a fake long-lived access token
- prefer in-memory auth session state for the scaffold
- preserve the vendor-owned multi-tenant Entra model and delegated auth direction

### Public feature scaffolding
Add public-facing placeholder screens/components for:
- public SIT/template library
- public DLP/template library
- public “how it works” / help page
- public rule-pack informational page
- public pricing/about/contact placeholder if needed for product shell completeness

These can use placeholder/local data in this phase, but structure them so they can later be backed by community/public DB data.

### Protected test console shell
Add a public test console page that is viewable anonymously, but gated when executing protected actions.

Required UX:
- user can see the file upload/test console UI without signing in
- the actual “Run Test-TextExtraction” / “Run Test-DataClassification” action requires auth
- if not authenticated, clicking run triggers protected-action auth flow
- if authenticated but consent is incomplete, show tenant consent requirement
- do not implement real worker/cmdlet execution yet; use structured placeholders

### Backend public/protected split
Introduce clear API separation:
- public endpoints that require no auth
- protected endpoints that require auth

Public endpoints may include placeholder responses for:
- public templates/library
- public app metadata/help/config

Protected endpoints should remain or expand for:
- me
- tenant summary
- consent status
- consent complete
- protected job request skeletons

### Protected job skeletons
Add placeholder protected endpoints and contracts for:
- `POST /api/v1/jobs/test-text-extraction`
- `POST /api/v1/jobs/test-data-classification`
- `GET /api/v1/jobs/{jobId}`

These should:
- require auth
- validate the request shape
- return placeholder queued/job-state responses
- not execute real PowerShell yet

### Shared contracts
Expand shared contracts for:
- public template/library items
- protected action state
- test job request/response models
- anonymous vs authenticated app state

### Tests
Add tests for:
- anonymous user can load public app shell
- anonymous user can browse public pages
- anonymous user attempting protected action gets auth prompt/gate
- authenticated user can see consent-dependent protected flow
- public endpoints do not require auth
- protected job endpoints do require auth

## Implementation notes
- preserve all valid Phase 0 and Phase 1 work
- do not rewrite the repo from scratch
- do not implement real MSAL auth flow unless it can be cleanly scaffolded without guessing
- do not implement real Exchange Online / IPPS execution in this phase
- do not implement real blob upload or SAS logic yet unless needed for a clean placeholder boundary
- do not implement full SIT/DLP editors yet
- prefer small, reviewable diffs
- expand shared packages instead of creating disconnected types in app folders

## Acceptance criteria
- the app can be opened and meaningfully browsed without sign-in
- public pages exist and do not trigger protected API calls automatically
- protected actions trigger auth only when requested
- consent/onboarding UI is no longer the primary default experience
- protected job request placeholders exist for text extraction and data classification
- auth/session scaffold is cleaner and less dependent on localStorage placeholder token persistence
- tests cover anonymous and protected-action flows

## Out of scope
- real PowerShell worker execution
- real file upload to blob/SAS
- real Test-TextExtraction execution
- real Test-DataClassification execution
- real tenant dictionary sync
- real community library backend persistence
- full SIT/DLP authoring