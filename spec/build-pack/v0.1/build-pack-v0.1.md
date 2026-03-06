# Build Pack v0.1 — Purview SIT/DLP Authoring Platform
`spec/build-pack/v0.1/README.md`

***

## SECTION A — Executive Implementation Summary

### Architecture in one paragraph

A React SPA (`apps/web`) calls a stateless Node/FastAPI backend (`apps/api`). The backend enqueues short-lived PowerShell jobs onto Azure Service Bus. Containerized workers (`apps/worker`) pick up jobs, run `Connect-ExchangeOnline` or `Connect-IPPSSession` using a delegated token passed in the job payload, execute the requested cmdlets, and return structured JSON. All persistence flows through a single PostgreSQL database with row-level security (RLS) enforced on `tenant_id`. A vendor-owned multi-tenant Entra app handles auth; customers complete one-time admin consent. No customer-side app registration is required.[1]

### Why it satisfies feasibility findings

- Delegated token + `-AccessToken` parameter on `Connect-ExchangeOnline` / `Connect-IPPSSession` is confirmed working for short-lived server-side use. Long-lived unattended execution is explicitly **not assumed**.[1]
- `Export-DlpPolicyCollection` is retired for cloud tenants; DLP export is implemented via `Get-DlpCompliancePolicy` + `Get-DlpComplianceRule` + JSON serialization only.[1]
- Containerized workers provide per-job isolation, per-tenant concurrency caps, and clean runspace teardown.[1]

### MVP vs Phase 2

| Included in MVP | Deferred to Phase 2 |
|---|---|
| Sign-in + tenant consent flow | App-only / cert-based auth (future optional) |
| `Test-TextExtraction` + `Test-DataClassification` jobs | Scheduled/recurring background jobs |
| SIT authoring wizard (full pattern model) | Trainable classifiers integration |
| XML rule pack import/export | Bulk multi-tenant admin management |
| DLP policy/rule builder (Exchange, SPO, Teams, Endpoint) | Simulation engine against historical telemetry |
| Community library (publish/import) | Advanced NER model fine-tuning |
| Basic reporting (DLP policy/rule listing) | Purview Activity Explorer deep integration |
| Dark/light design system | Mobile-native app |

***

## SECTION B — Product Scope and Boundaries
`spec/build-pack/v0.1/scope.md`

### Goals

1. Web-only Microsoft Purview SIT and DLP authoring, testing, and export — no local installation required.
2. Multi-tenant SaaS with per-tenant private workspace.
3. Run Purview classification cmdlets server-side on behalf of a consented, signed-in user.
4. Guided wizard-first UX with inline help, Boost.Regex compatibility validation, and DLP workload awareness.
5. XML rule pack round-trip fidelity.
6. Optional community library for sharing sanitised artifacts.

### Non-Goals

- No local PowerShell execution in the browser.
- No app-only / certificate-based service principal auth in MVP.
- No customer-side Azure app registration.
- No persistent long-running delegated PowerShell sessions.
- No replacement of the Purview compliance portal as a primary admin surface.
- No on-premises Exchange support.

### MVP Scope (Phases 0–6)

Phases 0–6 from the delivery plan (Section P). Covers auth, consent, test jobs, SIT editor, XML engine, DLP builder.

### Phase 2 Scope (Phases 7–8+)

Community library, reporting/tuning, what-if simulation, advanced NER assistance, partner/GDAP admin flows.

### Explicitly Unsupported Behaviors

- **Unattended delegated execution**: The system will not schedule or run PowerShell jobs on behalf of a user when no user session is active. This is by design — delegated tokens cannot reliably outlive MFA/CA policy enforcement without user interaction.[1]
- **Token persistence beyond job lifetime**: Delegated access tokens are consumed and discarded after each job. Refresh tokens are **not** persisted in MVP.
- **Background jobs exceeding token boundaries**: Any job requiring more than a single short-lived token exchange is out of scope for MVP.
- **Cross-tenant data sharing**: No mechanism allows tenant A to read tenant B's workspace data.

***

## SECTION C — Application Structure / Repo Layout
`spec/build-pack/v0.1/repo-structure.md`

**Decision: monorepo with Turborepo** — shared types, contracts, and the rulepack engine are referenced by both frontend and backend without publishing to npm. Single CI pipeline manages all packages.

```
/ (repo root)
├── apps/
│   ├── web/                        # React 18 SPA (Vite, TypeScript)
│   │   ├── src/
│   │   │   ├── auth/               # MSAL browser wrapper, consent redirect
│   │   │   ├── features/
│   │   │   │   ├── sit/            # SIT authoring wizard, test console
│   │   │   │   ├── dlp/            # DLP builder, workload config
│   │   │   │   ├── rulepack/       # XML import/export UI
│   │   │   │   ├── dictionary/     # Keyword dictionary manager
│   │   │   │   ├── community/      # Browse/publish/import community
│   │   │   │   ├── reporting/      # DLP policy listing, tuning view
│   │   │   │   └── onboarding/     # Tenant consent wizard
│   │   │   ├── components/         # Design system consumers
│   │   │   ├── hooks/
│   │   │   ├── store/              # Zustand or Redux Toolkit slices
│   │   │   └── utils/
│   │   └── vite.config.ts
│   │
│   ├── api/                        # FastAPI (Python 3.12) or Node/Express
│   │   ├── src/
│   │   │   ├── auth/               # Token validation, tenant resolution
│   │   │   ├── routes/             # All HTTP route handlers
│   │   │   ├── services/
│   │   │   │   ├── job_service.py  # Enqueue + poll job results
│   │   │   │   ├── sit_service.py
│   │   │   │   ├── dlp_service.py
│   │   │   │   ├── rulepack_service.py
│   │   │   │   ├── community_service.py
│   │   │   │   └── dictionary_service.py
│   │   │   ├── db/                 # SQLAlchemy models + Alembic migrations
│   │   │   ├── queue/              # Azure Service Bus client
│   │   │   ├── storage/            # Azure Blob storage client
│   │   │   └── observability/      # OpenTelemetry setup
│   │   └── Dockerfile
│   │
│   └── worker/                     # PowerShell 7 + ExchangeOnlineManagement
│       ├── src/
│       │   ├── JobRunner.ps1       # Main dispatch loop
│       │   ├── jobs/
│       │   │   ├── TestTextExtraction.ps1
│       │   │   ├── TestDataClassification.ps1
│       │   │   ├── GetClassificationRulePacks.ps1
│       │   │   ├── SetClassificationRuleCollection.ps1
│       │   │   ├── GetDlpPolicies.ps1
│       │   │   ├── GetDlpRules.ps1
│       │   │   ├── ExportDlpDefinitions.ps1
│       │   │   └── DictionaryOps.ps1
│       │   ├── auth/
│       │   │   └── Connect-Tenant.ps1
│       │   └── output/
│       │       └── Serialize-Output.ps1
│       └── Dockerfile
│
├── packages/
│   ├── contracts/                  # Shared TypeScript types + OpenAPI schema
│   │   ├── src/
│   │   │   ├── jobs.ts
│   │   │   ├── sit.ts
│   │   │   ├── dlp.ts
│   │   │   ├── rulepack.ts
│   │   │   └── api.ts
│   │   └── package.json
│   │
│   ├── rulepack-engine/            # XML parse/generate/validate (TypeScript)
│   │   ├── src/
│   │   │   ├── parser.ts           # XML → internal model
│   │   │   ├── generator.ts        # Internal model → XML
│   │   │   ├── validator.ts        # Limit + schema checks
│   │   │   ├── differ.ts           # Version diff
│   │   │   └── schemas/            # XSD or JSON schema refs
│   │   └── package.json
│   │
│   ├── design-system/              # Radix UI + Tailwind component library
│   │   ├── src/
│   │   │   ├── components/
│   │   │   ├── tokens/             # Color, spacing, typography tokens
│   │   │   └── themes/             # dark.ts, light.ts
│   │   └── package.json
│   │
│   └── regex-compat/               # Boost.Regex 5.1.3 compatibility checker
│       ├── src/
│       │   ├── checker.ts
│       │   └── unsupported-constructs.ts
│       └── package.json
│
├── infra/
│   ├── terraform/
│   │   ├── modules/
│   │   │   ├── aks/                # Worker container cluster
│   │   │   ├── postgres/           # Azure Database for PostgreSQL
│   │   │   ├── servicebus/         # Job queue
│   │   │   ├── storage/            # Blob (file uploads)
│   │   │   ├── keyvault/           # Secrets
│   │   │   └── appservice/         # API host
│   │   └── main.tf
│   └── docker/
│       ├── worker.Dockerfile
│       └── api.Dockerfile
│
├── spec/
│   └── build-pack/
│       └── v0.1/                   # This document + all section files
│
├── tests/
│   ├── e2e/                        # Playwright
│   ├── api/                        # pytest
│   └── worker/                     # Pester (PowerShell)
│
├── turbo.json
├── package.json (root)
└── pnpm-workspace.yaml
```

### Boundary Rules

| Concern | Belongs in |
|---|---|
| MSAL token acquisition | `apps/web/src/auth/` |
| Token validation (JWT verify) | `apps/api/src/auth/` |
| Tenant resolution from `tid` claim | `apps/api/src/auth/` |
| Job enqueueing | `apps/api/src/queue/` |
| PowerShell cmdlet execution | `apps/worker/` **only** |
| XML parse/generate/validate | `packages/rulepack-engine/` |
| Shared request/response types | `packages/contracts/` |
| UI components | `packages/design-system/` |
| Regex compat checks | `packages/regex-compat/` |

***

## SECTION D — Refined System Architecture
`spec/build-pack/v0.1/architecture.md`

### Component Responsibilities

**Frontend (`apps/web`)**
- MSAL.js auth with PKCE code flow for SaaS backend scope.
- Separate OAuth popup/redirect for `Exchange.Manage` / IPPS scope (tenant-bound token for job use).
- Wizard orchestration state machine (XState or Zustand finite state).
- Polling job status via `GET /jobs/{jobId}`.
- File upload to signed blob URL (never through the API server).
- XML preview/diff rendering.
- All UI, validation feedback, inline help.

**Backend API (`apps/api`)**
- JWT validation (`tid`, `oid`, `aud` claims verified on every request).
- Tenant isolation enforcement (every DB query includes `WHERE tenant_id = :tid`).
- CRUD for SIT drafts/versions, DLP models, dictionaries, community artifacts.
- File upload: issues short-lived Azure Blob SAS write URLs; stores blob reference.
- Job enqueueing: validates job payload, writes `job_runs` record, pushes to Service Bus.
- Job status polling: reads `job_runs` table.
- Rule pack XML generation: delegates to `rulepack-engine` library.
- Community library moderation endpoints.
- Never executes PowerShell directly.

**Worker (`apps/worker`)**
- Reads one message at a time from Service Bus.
- Validates job payload (tenant ID must match token `tid`).
- Calls `Connect-Tenant.ps1` → runs `Connect-ExchangeOnline -AccessToken` or `Connect-IPPSSession -AccessToken` with provided token.
- Dispatches to job-specific `.ps1` script.
- Serializes output as JSON, writes result to `job_runs` via internal callback HTTP endpoint on the API (or directly to DB via worker DB credential).
- Calls `Disconnect-ExchangeOnline` / `Disconnect-IPPSSession`.
- Posts completion/error status.
- Tears down runspace.
- Never caches tokens or tenant session state between jobs.

**Queue / Job Orchestration**
- Azure Service Bus Standard tier, single queue `purview-jobs`.
- Message TTL: 10 minutes. Dead-letter queue enabled.
- Lock duration: 3 minutes (covers expected max job time).
- Per-tenant in-flight message count tracked in Redis or DB; cap = 3 concurrent jobs per tenant.

**File Upload / Storage**
- Files uploaded directly from browser to Azure Blob Storage via SAS URL (issued by API, 5-min TTL).
- Blob reference stored in `job_runs.input_blob_ref`.
- Worker downloads blob at job start using a worker-scoped managed identity.
- Blob deleted after job completion (or retained for 24h if result references it).

**Database**
- PostgreSQL 16 with RLS policies on `tenant_id`.
- Alembic for migrations.
- All writes go through API; worker writes only to `job_runs` via a restricted DB role.

**Observability**
- OpenTelemetry SDK in both `api` and `worker`.
- Traces exported to Azure Monitor / Application Insights.
- Structured JSON logs (correlation ID on every log line).
- Azure Service Bus queue depth metric → alert if > 50 messages.

### Synchronous vs Asynchronous

| Operation | Mode |
|---|---|
| CRUD SIT/DLP models | Sync |
| XML parse/validate on import | Sync (< 200ms expected) |
| XML generate on export | Sync |
| Community library browse/search | Sync |
| `Test-TextExtraction` | Async (job) |
| `Test-DataClassification` | Async (job) |
| List DLP policies/rules | Async (job) |
| Import rule pack to tenant | Async (job) |
| Export DLP definitions | Async (job) |
| Dictionary read/write to tenant | Async (job) |

### Request Lifecycle Summaries

**Sign-in + Consent**
```
Browser → MSAL.js auth code + PKCE → Entra /authorize
→ Entra returns code → MSAL exchanges for id_token + access_token (SaaS backend audience)
→ SPA stores in memory (no localStorage)
→ API validates JWT on every request
→ Consent flow: SPA opens /adminconsent URL in popup
→ Admin approves → Entra creates SP in customer tenant
→ API stores tenant record (tenant_id, consent_scopes, onboarded_at)
```

**Run Test-TextExtraction**
```
1. User uploads file → API issues SAS URL → browser uploads to Blob
2. Browser requests Exchange.Manage token (popup OAuth flow, tenant-scoped)
3. Browser POSTs {accessToken, blobRef, tenantId} to POST /jobs
4. API validates token claims, writes job_runs record, enqueues to Service Bus
5. Worker dequeues, downloads blob, Connect-ExchangeOnline -AccessToken $token
6. Runs Test-TextExtraction -FileData $content
7. Serializes result to JSON, PATCHes job_runs.result via API callback
8. Browser polls GET /jobs/{id} → receives result
9. Worker Disconnect-ExchangeOnline, runspace dispose
```

**Import XML Rule Pack**
```
1. User uploads XML → Blob SAS write → blob stored
2. API receives POST /rulepacks/import with blobRef
3. rulepack-engine parser runs synchronously against blob content
4. Validation report returned immediately (no job needed for parse)
5. If user confirms push-to-tenant: POST /jobs {type: SET_RULE_COLLECTION, payload: {xml, tenantId}}
6. Worker runs Set-ClassificationRuleCollection with the XML
```

**Export Custom SIT Rule Pack**
```
1. User selects SITs → POST /rulepacks/export {sitIds[]}
2. API fetches SIT records, calls rulepack-engine.generate()
3. Returns XML as download (sync, no job)
4. Optional: user clicks "Push to tenant" → async job
```

**List Tenant DLP Policies/Rules**
```
1. User triggers "Sync from tenant"
2. Browser acquires IPPS-scoped token (popup)
3. POST /jobs {type: GET_DLP_POLICIES, accessToken, tenantId}
4. Worker: Connect-IPPSSession -AccessToken
5. Get-DlpCompliancePolicy | Get-DlpComplianceRule (per policy)
6. Serialize to JSON, return via job result
7. API maps to dlp_policies + dlp_rules tables (upsert, tagged as tenant_snapshot)
```

***

## SECTION E — Authentication and Consent Design
`spec/build-pack/v0.1/auth.md`

### Sign-in Flow

```
[Browser]                    [Entra /authorize]              [API]
   |                                |                           |
   |-- MSAL.js auth code PKCE ----->|                           |
   |<-- code ----------------------|                           |
   |-- code + verifier (MSAL) ----->|                           |
   |<-- id_token + access_token ---|                           |
   |                                                           |
   |-- GET /api/me (Bearer access_token) ---------------------->|
   |                                              validate JWT  |
   |                                              extract tid, oid, upn
   |<-- {user, tenant_status} ----------------------------------|
```

### Tenant Onboarding / Admin Consent Flow

```
[SPA]                         [Admin Browser]            [Entra]           [API]
  |                                |                        |                 |
  |-- render consent URL ---------->|                        |                 |
  | (.../adminconsent?client_id=VENDOR_APP_ID&redirect_uri=...)
  |                                |-- navigate to URL ----->|                 |
  |                                |<-- consent prompt ------|                 |
  |                                |-- admin approves ------>|                 |
  |                                |<-- redirect to callback URL              |
  |                                                          |                 |
  |-- POST /api/tenants/consent-complete {tenantId, state} -------------------->|
  |                                                                  write tenant record
  |<-- {status: "onboarded"} --------------------------------------------------|
```

**State parameter**: CSRF token (UUID), stored in session; verified on callback.

### Token Handling Rules

| Rule | Implementation |
|---|---|
| SaaS backend access token | Stored in MSAL in-memory cache only. Never localStorage/sessionStorage. |
| Exchange/IPPS delegated token | Acquired in a separate OAuth popup scoped to `Exchange.Manage` / IPPS scope. Short-lived. |
| Token for worker job | POSTed to `POST /jobs` over HTTPS. Stored encrypted in `job_runs.encrypted_token` for duration of job only. |
| Token after job completion | Deleted from `job_runs` record (set to NULL). Not logged. |
| Refresh tokens | **Not persisted in MVP.** If user session expires, user re-auths. |
| Token forwarding to worker | Job payload field `token` (encrypted at rest in Service Bus message via Service Bus message encryption + AES-256 envelope). |

### Session Model

- SPA session: MSAL session in browser memory. `sessionStorage` for MSAL cache (cleared on tab close).
- Backend: **stateless** — no server-side session cookies. Every request carries JWT.
- Anti-CSRF: for state-changing requests, SPA sends `X-Request-ID` header; backend verifies it is not a CORS preflight replay.

### Tenant Identity Derivation

```python
# In API auth middleware
tid = jwt_claims["tid"]           # always from token
oid = jwt_claims["oid"]           # user object ID
upn = jwt_claims.get("upn") or jwt_claims.get("preferred_username")
tenant = db.query(Tenant).filter_by(entra_tenant_id=tid).first()
if not tenant or not tenant.consent_complete:
    raise HTTPException(403, "Tenant not onboarded")
```

`tid` is the enforcement key for every DB query.

### Required Delegated Permissions (Documented)

| Scope | Purpose | Documented? |
|---|---|---|
| `openid profile email` | Sign-in | ✅ Documented |
| `offline_access` | Refresh token (future optional) | ✅ Documented |
| `Exchange.Manage` | `Connect-ExchangeOnline -AccessToken` | ✅ Documented (michev.info + MS docs) |
| IPPS `user_impersonation` | `Connect-IPPSSession -AccessToken` | ⚠️ Inferred — see Section Q |

### Required Purview Roles (Customer Tenant)

| Role | Required for | Documented? |
|---|---|---|
| Compliance Administrator | DLP + SIT cmdlets via IPPS | ✅ |
| Security Administrator | SIT read/write | ✅ |
| Exchange Administrator | `Test-TextExtraction`, `Test-DataClassification` | ⚠️ Inferred — needs dev tenant validation |
| DLP Compliance Management | `New/Set-DlpCompliancePolicy/Rule` | ✅ |

***

## SECTION F — PowerShell Worker Execution Design
`spec/build-pack/v0.1/worker.md`

### Worker Startup Model

Worker containers run as AKS pods. On startup:
1. Import `ExchangeOnlineManagement` module (pre-installed in image).
2. Start Service Bus message pump (long-poll with 60s timeout).
3. Process one message at a time per pod (no parallel runspaces in one pod — simpler isolation).
4. Scale pods horizontally via KEDA on Service Bus queue depth.

### Job Schema

```json
{
  "jobId": "uuid",
  "tenantId": "entra-tenant-guid",
  "userId": "entra-oid",
  "jobType": "TEST_TEXT_EXTRACTION | TEST_DATA_CLASSIFICATION | GET_CLASSIFICATION_RULE_PACKS | SET_CLASSIFICATION_RULE_COLLECTION | GET_DLP_POLICIES | GET_DLP_RULES | EXPORT_DLP_DEFINITIONS | DICTIONARY_READ | DICTIONARY_WRITE",
  "accessToken": "eyJ...",          // delegated, short-lived
  "accessTokenExpiry": "ISO8601",
  "delegatedOrg": "contoso.com",    // optional, for partner/GDAP scenarios
  "payload": { /* job-specific */ },
  "enqueuedAt": "ISO8601",
  "timeoutSeconds": 120
}
```

### Runspace / Session Lifecycle

```
1. Receive job message from Service Bus (lock acquired)
2. Validate: jobId exists in DB, tenantId matches token tid claim, token not expired
3. Create new PowerShell runspace (Add-Type / CreateRunspace)
4. Connect-Tenant.ps1:
   - If jobType requires EXO: Connect-ExchangeOnline -AccessToken $token [-DelegatedOrganization $delegatedOrg]
   - If jobType requires IPPS: Connect-IPPSSession -AccessToken $token [-DelegatedOrganization $delegatedOrg]
5. Dispatch to job handler script
6. Capture output (ConvertTo-Json)
7. Disconnect-ExchangeOnline / Disconnect-IPPSSession
8. Dispose runspace
9. POST result to API callback: PATCH /internal/jobs/{jobId}/result
10. Complete Service Bus message (delete lock)
```

On any error in steps 4–8: catch exception, mark job FAILED, still disconnect + dispose.

### Per-Job Isolation

- Each job runs in a fresh runspace. No session reuse between jobs.
- No shared PowerShell module-level state between jobs.
- Container's file system: temp files written to `/tmp/{jobId}/`, deleted after job.

### Per-Tenant Concurrency Controls

- `job_runs` table has column `tenant_id`. API enforces: `SELECT COUNT(*) WHERE tenant_id=X AND status IN ('QUEUED','RUNNING') <= 3` before enqueueing.
- Reject with `429 Too Many Requests` if limit exceeded.
- Worker also checks this before processing (defense in depth).

### Timeouts

| Job Type | Timeout |
|---|---|
| TEST_TEXT_EXTRACTION | 60s |
| TEST_DATA_CLASSIFICATION | 90s |
| GET_CLASSIFICATION_RULE_PACKS | 60s |
| SET_CLASSIFICATION_RULE_COLLECTION | 120s |
| GET_DLP_POLICIES + RULES | 120s |
| EXPORT_DLP_DEFINITIONS | 120s |
| DICTIONARY_READ/WRITE | 60s |

### Retry Rules

- Transient errors (throttle `429`, network timeout): retry up to 3× with exponential backoff (5s, 15s, 45s).
- Auth failure (401/403): no retry. Job marked `AUTH_FAILED`. User must re-auth.
- Token expired at execution time: no retry. Job marked `TOKEN_EXPIRED`.
- Hard failure (unhandled exception): 1 retry, then `FAILED`.

### Output Shaping

Workers produce **typed, minimal JSON** — only fields needed by the UI. Raw Exchange/Purview object graphs are never stored.

```json
// Example: TEST_DATA_CLASSIFICATION result
{
  "jobId": "...",
  "status": "COMPLETED",
  "completedAt": "ISO8601",
  "result": {
    "classifications": [
      {
        "sitName": "Credit Card Number",
        "sitId": "guid",
        "confidence": "High",
        "count": 3,
        "matches": [
          { "snippet": "...[REDACTED]...", "position": 42, "length": 16 }
        ]
      }
    ]
  }
}
```

### Error Taxonomy

| Code | Meaning |
|---|---|
| `CONNECT_FAILED` | Connect-ExchangeOnline / Connect-IPPSSession failed |
| `AUTH_FAILED` | Token rejected by Exchange/IPPS |
| `TOKEN_EXPIRED` | Token expired before job could start |
| `CMDLET_ERROR` | Cmdlet threw a terminating error |
| `THROTTLED` | Exchange throttling; retry attempted |
| `TIMEOUT` | Job exceeded timeout |
| `VALIDATION_ERROR` | Job payload failed pre-execution validation |
| `TENANT_MISMATCH` | Token tid ≠ job tenantId |

### What Is Persisted vs Transient

| Data | Storage |
|---|---|
| Job status, type, timestamps | Persisted in `job_runs` |
| Structured result JSON (classification results, policy lists) | Persisted in `job_runs.result_json` (24h TTL then nulled) |
| Uploaded file content | Blob storage (deleted after job) |
| Raw cmdlet output objects | **Never persisted** |
| Access tokens in job record | Nulled after job completion |
| PowerShell error detail (full stack) | Logs only, never to DB |

### Audit Logging Events (Worker)

- `WORKER_JOB_STARTED {jobId, tenantId, jobType}`
- `WORKER_CONNECT_ATTEMPT {jobId, endpoint}`
- `WORKER_CONNECT_SUCCESS {jobId, endpoint, durationMs}`
- `WORKER_CONNECT_FAILED {jobId, endpoint, error_code}` (no token logged)
- `WORKER_CMDLET_EXECUTED {jobId, cmdlet, durationMs, resultCount}`
- `WORKER_JOB_COMPLETED {jobId, status, durationMs}`

***

## SECTION G — Data Model and Storage Design
`spec/build-pack/v0.1/data-model.md`

### ERD (Text Form)

```
users ──< tenant_memberships >── tenants
tenants ──< sit_drafts
tenants ──< sit_versions
tenants ──< dlp_policies ──< dlp_rules
tenants ──< keyword_dictionaries
tenants ──< job_runs
tenants ──< test_runs ──< test_run_results
tenants ──< imported_rulepacks ──< imported_rulepack_sits
tenants ──< audit_events

sit_drafts ──< sit_patterns ──< sit_elements
sit_drafts ──> sit_versions (on publish)
sit_versions ──> community_artifacts (on publish)

community_artifacts ──< artifact_tags
artifact_tags >── tags
```

### Table Definitions

```sql
-- TENANTS
CREATE TABLE tenants (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entra_tenant_id    VARCHAR(36) UNIQUE NOT NULL,
  primary_domain     VARCHAR(255),
  display_name       VARCHAR(255),
  consent_complete   BOOLEAN DEFAULT FALSE,
  consent_scopes     JSONB,
  onboarded_at       TIMESTAMPTZ,
  deleted_at         TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- USERS
CREATE TABLE users (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entra_oid      VARCHAR(36) UNIQUE NOT NULL,
  upn            VARCHAR(255),
  display_name   VARCHAR(255),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- TENANT_MEMBERSHIPS
CREATE TABLE tenant_memberships (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES tenants(id),
  user_id     UUID NOT NULL REFERENCES users(id),
  role        VARCHAR(50) NOT NULL DEFAULT 'member', -- 'owner','admin','member'
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, user_id)
);

-- SIT_DRAFTS
CREATE TABLE sit_drafts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  owner_user_id   UUID REFERENCES users(id),
  name            VARCHAR(255) NOT NULL,
  description     TEXT,
  category        VARCHAR(100),
  tags            JSONB DEFAULT '[]',
  status          VARCHAR(50) DEFAULT 'draft', -- draft, ready, archived
  version_label   VARCHAR(50) DEFAULT '1.0.0',
  sit_guid        UUID NOT NULL DEFAULT gen_random_uuid(), -- stable SIT identity across versions
  locale          VARCHAR(10) DEFAULT 'en-US',
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- SIT_PATTERNS
CREATE TABLE sit_patterns (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sit_draft_id     UUID NOT NULL REFERENCES sit_drafts(id) ON DELETE CASCADE,
  pattern_index    INTEGER NOT NULL,
  confidence_level VARCHAR(20) NOT NULL, -- Low, Medium, High
  proximity_mode   VARCHAR(20) DEFAULT 'Relaxed', -- Relaxed, Anywhere, Custom
  proximity_value  INTEGER,              -- char distance, for Custom
  group_logic      VARCHAR(20) DEFAULT 'Any', -- Any, All, NotAny
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- SIT_ELEMENTS
CREATE TABLE sit_elements (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern_id       UUID NOT NULL REFERENCES sit_patterns(id) ON DELETE CASCADE,
  element_role     VARCHAR(20) NOT NULL, -- primary, supporting
  element_type     VARCHAR(30) NOT NULL, -- Regex, KeywordList, KeywordDictionary, Function
  element_index    INTEGER NOT NULL,
  regex_pattern    TEXT,
  regex_validators JSONB DEFAULT '[]',   -- [{type: "Luhn"}, ...]
  keyword_list     JSONB DEFAULT '[]',   -- ["visa","mastercard"]
  dictionary_id    UUID REFERENCES keyword_dictionaries(id),
  function_name    VARCHAR(100),
  additional_checks JSONB DEFAULT '{}',  -- {excludeRepeatedDigits: true, ...}
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- SIT_VERSIONS (immutable snapshots)
CREATE TABLE sit_versions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sit_draft_id    UUID NOT NULL REFERENCES sit_drafts(id),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  version_label   VARCHAR(50) NOT NULL,
  sit_guid        UUID NOT NULL,
  snapshot_json   JSONB NOT NULL,        -- full SIT structure at this version
  rulepack_xml    TEXT,                  -- generated XML at this version
  published_by    UUID REFERENCES users(id),
  published_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(sit_draft_id, version_label)
);

-- KEYWORD_DICTIONARIES
CREATE TABLE keyword_dictionaries (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL REFERENCES tenants(id),
  name         VARCHAR(255) NOT NULL,
  description  TEXT,
  terms        JSONB NOT NULL DEFAULT '[]',
  term_count   INTEGER GENERATED ALWAYS AS (jsonb_array_length(terms)) STORED,
  size_bytes   INTEGER,
  deleted_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- DLP_POLICIES
CREATE TABLE dlp_policies (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  name            VARCHAR(255) NOT NULL,
  suggested_name  VARCHAR(255),
  description     TEXT,
  workload        VARCHAR(50) NOT NULL, -- Exchange, SharePoint, Teams, Endpoint
  mode            VARCHAR(30) DEFAULT 'TestWithoutNotifications', -- Enforce, TestWithNotifications, TestWithoutNotifications
  status          VARCHAR(30) DEFAULT 'draft',
  is_tenant_snapshot BOOLEAN DEFAULT FALSE, -- synced from tenant, read-only
  snapshot_policy_id VARCHAR(255),      -- GUID from Get-DlpCompliancePolicy
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- DLP_RULES
CREATE TABLE dlp_rules (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id       UUID NOT NULL REFERENCES dlp_policies(id) ON DELETE CASCADE,
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  name            VARCHAR(255) NOT NULL,
  suggested_name  VARCHAR(255),
  rule_index      INTEGER NOT NULL,
  conditions      JSONB NOT NULL DEFAULT '{}',
  actions         JSONB NOT NULL DEFAULT '{}',
  exceptions      JSONB DEFAULT '{}',
  locations       JSONB DEFAULT '{}',
  severity        VARCHAR(20) DEFAULT 'Medium', -- Low, Medium, High
  is_enabled      BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- JOB_RUNS
CREATE TABLE job_runs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants(id),
  user_id          UUID NOT NULL REFERENCES users(id),
  job_type         VARCHAR(60) NOT NULL,
  status           VARCHAR(30) DEFAULT 'QUEUED', -- QUEUED, RUNNING, COMPLETED, FAILED, TOKEN_EXPIRED, AUTH_FAILED, TIMEOUT
  input_blob_ref   TEXT,
  input_payload    JSONB,
  result_json      JSONB,                -- nulled after 24h
  error_code       VARCHAR(50),
  error_summary    TEXT,                 -- user-safe message only
  encrypted_token  TEXT,                -- nulled after job completes
  queued_at        TIMESTAMPTZ DEFAULT NOW(),
  started_at       TIMESTAMPTZ,
  completed_at     TIMESTAMPTZ,
  duration_ms      INTEGER
);

-- TEST_RUNS
CREATE TABLE test_runs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants(id),
  user_id          UUID REFERENCES users(id),
  job_run_id       UUID REFERENCES job_runs(id),
  sit_ids          JSONB DEFAULT '[]',   -- SIT GUIDs tested
  input_type       VARCHAR(20),          -- file, text
  input_file_name  VARCHAR(255),
  input_content_hash VARCHAR(64),        -- SHA-256 of input (not content itself)
  result_summary   JSONB,               -- {totalMatches: N, bySit: [...]}
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- IMPORTED_RULEPACKS
CREATE TABLE imported_rulepacks (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        UUID NOT NULL REFERENCES tenants(id),
  user_id          UUID REFERENCES users(id),
  file_name        VARCHAR(255),
  rulepack_id_guid UUID,
  publisher        VARCHAR(255),
  version          VARCHAR(50),
  raw_xml          TEXT,                 -- stored for round-trip
  parse_status     VARCHAR(30),          -- valid, invalid, partial
  parse_errors     JSONB,
  sit_count        INTEGER,
  imported_at      TIMESTAMPTZ DEFAULT NOW()
);

-- COMMUNITY_ARTIFACTS
CREATE TABLE community_artifacts (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  artifact_type    VARCHAR(20) NOT NULL, -- sit, dlp_policy
  name             VARCHAR(255) NOT NULL,
  description      TEXT,
  structure_json   JSONB NOT NULL,       -- sanitized, no tenant IDs
  author_alias     VARCHAR(100),         -- anonymized
  region           VARCHAR(50),
  industry         VARCHAR(100),
  regulatory_mapping VARCHAR(255),
  workloads        JSONB DEFAULT '[]',
  moderation_status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
  moderation_notes TEXT,
  download_count   INTEGER DEFAULT 0,
  published_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ARTIFACT_TAGS + TAGS
CREATE TABLE tags (
  id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name  VARCHAR(100) UNIQUE NOT NULL,
  slug  VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE artifact_tags (
  artifact_id UUID NOT NULL REFERENCES community_artifacts(id) ON DELETE CASCADE,
  tag_id      UUID NOT NULL REFERENCES tags(id),
  PRIMARY KEY (artifact_id, tag_id)
);

-- AUDIT_EVENTS
CREATE TABLE audit_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID REFERENCES tenants(id),
  user_id      UUID REFERENCES users(id),
  event_type   VARCHAR(100) NOT NULL,
  resource_type VARCHAR(50),
  resource_id  UUID,
  details      JSONB DEFAULT '{}',      -- action-specific, no PII
  ip_address   INET,                    -- stored hashed
  created_at   TIMESTAMPTZ DEFAULT NOW()
);
```

### Key Indexes

```sql
CREATE INDEX idx_sit_drafts_tenant ON sit_drafts(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_sit_patterns_draft ON sit_patterns(sit_draft_id);
CREATE INDEX idx_sit_elements_pattern ON sit_elements(pattern_id);
CREATE INDEX idx_dlp_policies_tenant ON dlp_policies(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_dlp_rules_policy ON dlp_rules(policy_id);
CREATE INDEX idx_job_runs_tenant_status ON job_runs(tenant_id, status);
CREATE INDEX idx_audit_events_tenant_created ON audit_events(tenant_id, created_at DESC);
CREATE INDEX idx_community_artifacts_status ON community_artifacts(moderation_status);
```

### Row-Level Security

```sql
ALTER TABLE sit_drafts ENABLE ROW LEVEL SECURITY;
CREATE POLICY sit_drafts_tenant_isolation ON sit_drafts
  USING (tenant_id = current_setting('app.current_tenant_id')::UUID);
-- Repeat for all tenant-scoped tables
```

API sets `SET LOCAL app.current_tenant_id = '...'` at the start of each request transaction.

### Versioning Strategy

| Artifact | Strategy |
|---|---|
| SIT draft | Mutable `sit_drafts`. On "publish," create immutable `sit_versions` snapshot. |
| DLP draft | Mutable `dlp_policies`/`dlp_rules`. Version via `updated_at` + audit trail. |
| Community artifacts | Immutable once approved. New version = new artifact row. |
| Imported rule packs | Stored as-is in `imported_rulepacks`. Edits create `sit_drafts` copies. |

***

## SECTION H — SIT Domain Model and Authoring Engine
`spec/build-pack/v0.1/sit-domain-model.md`

### Type Definitions (TypeScript — `packages/contracts/src/sit.ts`)

```typescript
export type ConfidenceLevel = 'Low' | 'Medium' | 'High';
export type ProximityMode = 'Relaxed' | 'Anywhere' | 'Custom';
export type GroupLogic = 'Any' | 'All' | 'NotAny';
export type ElementType = 'Regex' | 'KeywordList' | 'KeywordDictionary' | 'Function';
export type ElementRole = 'primary' | 'supporting';

export interface RegexValidator {
  type: 'Luhn' | 'Date' | 'AvgWordLength' | 'CUSIPChecksum' | 'ISINChecksum' | string;
  parameters?: Record<string, string>;
}

export interface AdditionalChecks {
  excludeSpecificMatches?: string[];
  excludeRepeatedDigits?: boolean;
  excludeDuplicateCharacters?: boolean;
  requirePrefix?: string[];
  requireSuffix?: string[];
  excludePrefix?: string[];
  excludeSuffix?: string[];
  minLength?: number;
  maxLength?: number;
}

export interface SITElement {
  id: string;
  role: ElementRole;
  type: ElementType;
  regexPattern?: string;
  regexValidators?: RegexValidator[];
  keywordList?: string[];
  dictionaryId?: string;
  functionName?: string;
  additionalChecks?: AdditionalChecks;
}

export interface SITPattern {
  id: string;
  patternIndex: number;
  confidenceLevel: ConfidenceLevel;
  proximityMode: ProximityMode;
  proximityValue?: number;   // chars, for Custom mode
  groupLogic: GroupLogic;
  primaryElement: SITElement;
  supportingElements: SITElement[];
}

export interface SITDraft {
  id: string;
  sitGuid: string;          // stable GUID for rule pack identity
  tenantId: string;
  name: string;
  description?: string;
  category?: string;
  tags: string[];
  locale: string;           // e.g. "en-US"
  versionLabel: string;     // semver string
  patterns: SITPattern[];
  status: 'draft' | 'ready' | 'archived';
}

export interface RulePackIdentity {
  rulePackId: string;       // GUID
  publisher: string;
  version: string;          // e.g. "16.0.0.0"
  localeName: string;
  localeDescription: string;
}
```

### Validation Logic Rules

| Rule | Scope | Blocking? |
|---|---|---|
| At least 1 pattern per SIT | Client + Server | ✅ |
| At least 1 primary element per pattern | Client + Server | ✅ |
| Max 20 distinct regex patterns per SIT | Client + Server | ✅ |
| Regex length ≤ 1024 chars | Client + Server | ✅ |
| Keyword list: max 2048 terms, max 50 chars/term | Client + Server | ✅ |
| Dictionary size ≤ ~1MB post-compression | Server | ✅ |
| Max 50 SITs per rule package | Server (at export) | ✅ |
| Max rule package size 150KB | Server (at export) | ✅ |
| Max 10 rule packages per tenant | Server | ⚠️ Warning |
| SIT name: no duplicates in same tenant | Server | ✅ |
| Proximity `Custom` requires numeric value | Client | ✅ |

### Client-Side vs Server-Side Validation

- **Client-side (instant feedback)**: field length, required fields, regex syntax check (via `new RegExp()` + regex-compat package), keyword list term length, basic confidence/proximity enum checks.
- **Server-side (on save/export)**: aggregate limits (SIT count, package size, regex count), Boost.Regex compatibility pass via `regex-compat` package, duplicate name check, XML round-trip validate.

### Boost.Regex 5.1.3 Compatibility

The `packages/regex-compat` library maintains a list of known unsupported constructs:

```typescript
// packages/regex-compat/src/unsupported-constructs.ts
export const UNSUPPORTED_PATTERNS = [
  { pattern: /\(\?<[^!]/, description: 'Named capture groups (use (?P<name> syntax or anonymous)' },
  { pattern: /\\k</, description: 'Named backreferences' },
  { pattern: /\(\?(?!:|\=|!|<|P)/, description: 'Non-standard group syntax' },
  { pattern: /\(\?#/, description: 'Inline comments' },
  // ... extend from Boost.Regex 5.1.3 docs
];
```

**[RISK — see Section Q]**: The exact list of unsupported constructs is not fully documented. Must be validated in a dev tenant by running candidate patterns via `Test-DataClassification`.

### Example: Simple SIT

```json
{
  "name": "Contoso Employee ID",
  "sitGuid": "a1b2c3d4-...",
  "versionLabel": "1.0.0",
  "patterns": [
    {
      "confidenceLevel": "High",
      "proximityMode": "Relaxed",
      "groupLogic": "Any",
      "primaryElement": {
        "type": "Regex",
        "regexPattern": "\\bCEMP-\\d{6}\\b",
        "additionalChecks": { "excludeRepeatedDigits": true }
      },
      "supportingElements": [
        {
          "type": "KeywordList",
          "keywordList": ["employee id", "emp id", "contoso staff"],
          "role": "supporting"
        }
      ]
    }
  ]
}
```

### Example: Complex SIT (multiple patterns, supporting groups)

```json
{
  "name": "Contoso Payment Card",
  "sitGuid": "b2c3d4e5-...",
  "versionLabel": "2.1.0",
  "patterns": [
    {
      "confidenceLevel": "High",
      "proximityMode": "Custom",
      "proximityValue": 300,
      "groupLogic": "Any",
      "primaryElement": {
        "type": "Regex",
        "regexPattern": "\\b(?:4[0-9]{12}(?:[0-9]{3})?)\\b",
        "regexValidators": [{ "type": "Luhn" }],
        "additionalChecks": { "excludeRepeatedDigits": true, "excludeDuplicateCharacters": true }
      },
      "supportingElements": [
        { "type": "KeywordList", "keywordList": ["visa", "credit card"], "role": "supporting" },
        { "type": "KeywordList", "keywordList": ["cvv", "expiry", "exp"], "role": "supporting" }
      ]
    },
    {
      "confidenceLevel": "Medium",
      "proximityMode": "Relaxed",
      "groupLogic": "Any",
      "primaryElement": {
        "type": "Regex",
        "regexPattern": "\\b(?:4[0-9]{12}(?:[0-9]{3})?)\\b",
        "regexValidators": [{ "type": "Luhn" }]
      },
      "supportingElements": []
    },
    {
      "confidenceLevel": "Low",
      "proximityMode": "Anywhere",
      "groupLogic": "Any",
      "primaryElement": {
        "type": "Function",
        "functionName": "Func_credit_card"
      },
      "supportingElements": []
    }
  ]
}
```

***

## SECTION I — Rule Pack XML Import/Export Engine
`spec/build-pack/v0.1/rulepack-engine.md`

### Parsing Pipeline

```
1. Receive XML string
2. XML well-formedness check (DOMParser / fast-xml-parser)
3. Root element detection: <RulePackage> or <Rules> (ClassificationRuleCollection)
4. Schema validation against embedded XSD subset (MVP: structural, not full XSD)
5. Extract RulePackage identity: RulePackID, Publisher, Version, LocalizedStrings
6. For each <Entity> or <Affinity>: map to SITDraft
7. Map <Pattern> → SITPattern, <IdMatch> → primaryElement, <Match>/<Any> → supportingElements
8. Map <LocalizedStrings> → name/description per locale
9. Return: { identity: RulePackIdentity, sits: SITDraft[], parseErrors: ParseError[] }
```

### Validation Pipeline

```
1. Run all SIT limit checks (Section H validation table)
2. Run Boost.Regex compat check on all regex patterns
3. Check for duplicate SIT names within the pack
4. Check for duplicate GUIDs
5. Check total XML size ≤ 150KB
6. Return: ValidationResult { valid: boolean, errors: [], warnings: [] }
```

### Version Bump Strategy

On import of a rule pack that matches an existing `sit_draft.sit_guid`:
- If version is higher: offer merge (show diff, let user accept).
- If same version: warn "already imported at this version."
- If lower: warn "downgrade detected."

On export: version field incremented by user choice or auto-bumped (patch +1).

### GUID Handling

- GUIDs are preserved from the XML on import (stored in `sit_drafts.sit_guid`).
- On export: use the existing `sit_guid` if the SIT was imported; generate new UUID for new SITs.
- Rule pack GUID: auto-generated per tenant on first export; stable thereafter.

### Safe Import Rules

- Never auto-push imported XML to a tenant without explicit user confirmation.
- Imports land in `imported_rulepacks` as read-only source.
- User must explicitly clone to `sit_drafts` before editing.
- GUIDs from imports never overwrite existing tenant SIT GUIDs without conflict resolution flow.

### Localization Handling

- Parse all `<LocalizedStrings>` entries; store as `{locale: string, name: string, description: string}[]` in `sit_versions.snapshot_json`.
- Default display locale: `en-US`.
- On export: generate `<LocalizedStrings>` for all stored locales.

### Diff/Version Compare

The `packages/rulepack-engine/src/differ.ts` module:
- Compares two `SITDraft` objects field by field.
- Returns a `DiffResult` with added/removed/changed paths.
- UI renders this as a two-column side-by-side diff panel.

### MVP XML Support Scope

| Feature | MVP | Deferred |
|---|---|---|
| `<RulePackage>` root | ✅ | |
| `<Rules>` (ClassificationRuleCollection) root | ✅ | |
| `<Entity>` patterns | ✅ | |
| `<Affinity>` patterns | ⚠️ Partial parse | Full Affinity authoring |
| `<IdMatch>`, `<Match>`, `<Any>`, `<All>` | ✅ | |
| `<Validators>` | ✅ | |
| `<LocalizedStrings>` | ✅ | |
| Custom function references (`<Func_*>`) | ✅ parse, warn on unknown | Custom function authoring |
| `minCount`, `maxCount` attributes | ✅ | |
| `proximityDistance` | ✅ | |
| `<Version>` + `<Publisher>` | ✅ | |

***

## SECTION J — DLP Workload-Aware Builder Design
`spec/build-pack/v0.1/dlp-builder.md`

### Supported Workloads in MVP

Exchange Online, SharePoint/OneDrive, Teams, Endpoint DLP.

### Workload Capability Matrix

| Capability | Exchange | SharePoint/OD | Teams | Endpoint |
|---|---|---|---|---|
| Content contains SIT | ✅ | ✅ | ✅ | ✅ |
| Sender/recipient scope | ✅ | ❌ | ❌ | ❌ |
| Document properties | ❌ | ✅ | ❌ | ✅ |
| Sharing state | ❌ | ✅ | ❌ | ❌ |
| Device actions (copy/print) | ❌ | ❌ | ❌ | ✅ |
| Block with override | ✅ | ✅ | ✅ | ✅ |
| Policy tip | ✅ | ✅ | ✅ | ✅ |
| Email redirect | ✅ | ❌ | ❌ | ❌ |
| Restrict access | ❌ | ✅ | ✅ | ❌ |
| Encrypt | ✅ | ✅ | ❌ | ❌ |
| Alert admin | ✅ | ✅ | ✅ | ✅ |

### Naming Convention

**Policy:** `DLP-{Workload}-{Family}-{Mode}-P{###}`
- `{Workload}`: `EXO`, `SPO`, `TEAMS`, `EP`
- `{Family}`: short data family name (e.g., `PCI`, `HIPAA`, `GDPR`, `IP`)
- `{Mode}`: `Enforce`, `Test`, `Silent`
- `{###}`: zero-padded sequence (tenant-scoped)

**Rule:** `R{###}-{Action}-{Scenario}-{Signal}[-{Scope}][-Ex:{Key}]`
- Example: `R010-Block-External-Email-CreditCard-Ex:Internal`

The UI proposes the name on each step and shows a live preview of the assembled string. User can override any segment.

### Policy vs Rule Separation (UI Model)

```
Policy (one per workload per family)
├── metadata: name, workload, mode, locations, description
└── Rules (ordered list)
    ├── Rule 1: highest priority (block)
    │   ├── conditions: {sitIds: [...], minCount: 5, confidence: High}
    │   ├── actions: {blockAccess: true, notifyUser: true, policyTipText: "..."}
    │   └── exceptions: {senderDomain: "@contoso.com"}
    ├── Rule 2: medium (notify)
    └── Rule 3: lowest (audit only)
```

### Recommendation Engine Rules

| Recommendation | Trigger |
|---|---|
| "Use one policy per workload" | User adds second workload to existing policy |
| "High-confidence rule should be first" | Rules not ordered by descending confidence |
| "Test mode recommended for new policies" | User selects Enforce on first creation |
| "Add override-with-justification for internal users" | Block action without override option |
| "Exclude IT/compliance group from rules" | No exceptions defined |
| "Consider SIT minimum count ≥ 2 to reduce false positives" | minCount = 1 on low-confidence SIT |

### Export/Read Model for Existing Tenant DLP

Jobs `GET_DLP_POLICIES` + `GET_DLP_RULES`:
- `Get-DlpCompliancePolicy -Identity * | ConvertTo-Json`
- `Get-DlpComplianceRule -Policy $policy.Name | ConvertTo-Json`
- Mapped to `dlp_policies` + `dlp_rules` with `is_tenant_snapshot = TRUE`.
- Snapshots are read-only in UI — cloned to create editable copy.

### Worked Examples

**Exchange:**
```
Policy: DLP-EXO-PCI-Enforce-P001
  Rule R010-Block-External-Email-CreditCard
    Conditions: ContentContainsSIT(Credit Card Number, count≥1, confidence=High)
    Scope: SentTo(external)
    Actions: BlockMessage, NotifyUser, PolicyTip("Card numbers detected")
    Exceptions: SenderIn(DLP-Exclusion-Group)
  Rule R020-Notify-Internal-CreditCard
    Conditions: ContentContainsSIT(Credit Card Number, count≥1, confidence=Medium)
    Actions: NotifyUser, GenerateAlert(admin)
```

**SharePoint/OneDrive:**
```
Policy: DLP-SPO-GDPR-Test-P001
  Rule R010-Restrict-External-Share-PII
    Conditions: ContentContainsSIT(EU Personal Data, count≥1), SharedExternally=True
    Actions: RestrictAccess(external), NotifyUser
```

**Teams:**
```
Policy: DLP-TEAMS-HIPAA-Enforce-P001
  Rule R010-Block-PHI-External-Teams
    Conditions: ContentContainsSIT(PHI SITs, count≥1), MessageSentTo(external)
    Actions: BlockMessage, PolicyTip
```

**Endpoint:**
```
Policy: DLP-EP-IP-Enforce-P001
  Rule R010-Block-USB-Copy-IP
    Conditions: ContentContainsSIT(IP-Classifiers, count≥1), ActivityIs(CopyToUSB)
    Actions: BlockActivity, AuditActivity, NotifyUser
```

***

## SECTION K — Assisted Authoring / Phrase Extraction Pipeline
`spec/build-pack/v0.1/assisted-authoring.md`

### Pipeline Overview

```
[Upload] → [Blob Store]
    ↓
[Text Extraction]
  - .msg files: Test-TextExtraction (worker job)
  - .pdf/.docx/.txt: server-side python-docx / pdfplumber / plain text
    ↓
[Text Normalization]
  - Lowercase, remove control chars, normalize whitespace
  - Detect language (langdetect library)
  - Segment into sentences
    ↓
[Phrase Extraction — Deterministic]
  - TF-IDF over uploaded corpus (if multiple files)
  - RAKE (Rapid Automatic Keyword Extraction) for multi-word phrases
  - Enforce: max phrase length 50 chars (keyword list term limit)
  - Deduplicate; rank by frequency × distinctiveness
    ↓
[NER Pass — Heuristic]
  - spaCy en_core_web_sm (or similar small model, server-side)
  - Extract PERSON, ORG, CARDINAL, DATE entity types
  - Flag high-frequency NER tokens as supporting element candidates
    ↓
[Candidate Regex Generation — Rules-Based]
  - Detect high-entropy alpha-numeric tokens (e.g., account numbers)
  - Apply templates: \b[A-Z]{2}-\d{8}\b, etc.
  - Check generated regex length ≤ 1024 chars
  - Cap at 5 candidate regex suggestions (under 20-regex limit headroom)
    ↓
[Suggestions UI]
  - Show each candidate with: source text example, explanation, confidence estimate
  - User checkboxes: Accept / Modify / Discard
  - Accepted items populate SIT wizard fields directly
    ↓
[Test Round-Trip]
  - User clicks "Test against sample" → triggers Test-DataClassification job
  - UI shows match count per SIT per confidence level
```

### Deterministic vs Heuristic vs AI-Assisted

| Step | Type |
|---|---|
| Text normalization | Deterministic |
| RAKE phrase extraction | Rules-based (deterministic algorithm) |
| TF-IDF ranking | Deterministic |
| NER entity detection | Heuristic (ML model, lightweight) |
| Regex template matching | Rules-based |
| Regex suggestion generation | Rules-based with heuristics |
| Match testing via Test-DataClassification | Authoritative (Microsoft engine) |

**No LLM/generative AI in MVP** — all suggestions are rules-based and explainable. AI-assisted NER is bounded to the small spaCy model. This avoids data privacy concerns with sending tenant content to external AI services.

### Privacy / Safety Constraints

- Uploaded files are processed in-memory or in ephemeral temp storage only.
- No sample content is stored after the test run completes (beyond content hash for deduplication).
- Content is never used for model training.
- NER extraction results (entity strings) are held only in the user's session-scoped analysis job.
- Users explicitly approve each suggestion before it enters the SIT definition.

### Purview Platform Limit Guardrails

The pipeline hard-stops at:
- 20 distinct regex candidates per SIT.
- 2048 keyword suggestions per list.
- 50 chars per keyword term.
- 1024 chars per regex.

***

## SECTION L — UX / Design System / Information Architecture
`spec/build-pack/v0.1/ux.md`

### Top-Level Navigation

```
[Sidebar — collapsible]
├── 🏠 Dashboard
├── 🔬 Classification Lab
│   ├── My SITs
│   ├── Test Console
│   └── Keyword Dictionaries
├── 🛡️ DLP Builder
│   ├── My Policies
│   └── Tenant Snapshot
├── 📦 Rule Packs
│   ├── Import
│   └── Export
├── 🌐 Community Library
├── 📊 Reporting & Tuning
└── ⚙️ Settings
    ├── Tenant Connection
    ├── Consent Status
    └── Profile
```

### Main Screens

| Screen | Purpose |
|---|---|
| Dashboard | Consent status banner, recent activity, quick actions, job status widget |
| SIT List | Data table with search/filter, status chip (draft/ready/archived), last modified |
| SIT Editor (Wizard) | Multi-step form: Basics → Patterns → Validators → Preview → Save |
| Test Console | File upload or paste-text panel, SIT selector, real-time result display |
| DLP Policy List | Table of policies, workload badges, mode indicator, sync status |
| DLP Builder | Multi-step: Workload → Policy → Rules (ordered list editor) → Naming → Review |
| Rule Pack Import | File drop zone, parse report, conflict resolver, confirm push |
| Rule Pack Export | SIT selector with checkboxes, format picker, XML preview panel, download |
| Dictionary Manager | CRUD for keyword lists, upload CSV, size indicator with limit bar |
| Community Browse | Search/filter grid, preview drawer, one-click import |
| Reporting | DLP policy/rule listing, match volume charts (Phase 8) |
| Settings/Consent | Tenant onboarding wizard, consent status, re-consent button |

### Wizard / Stepper Model

All multi-step flows use a horizontal stepper (≤ 6 steps):

```
[Step 1 ●]──[Step 2 ●]──[Step 3 ○]──[Step 4 ○]
  Basics      Patterns    Validate    Review
```

- Steps are individually saveable as drafts.
- Navigating backward preserves all state.
- Validation errors on a step show a red dot on the stepper indicator.
- "Review" step is always the last — shows full JSON + XML preview.

### Empty States

Every empty state includes:
- Descriptive icon (not generic)
- "What you can do here" sentence
- Primary CTA button
- Link to relevant docs

Example — empty SIT list: *"You haven't created any Sensitive Information Types yet. SITs define the patterns that DLP policies use to detect sensitive content."* [Create SIT] [Import from XML]

### Error States

- **Field validation**: inline red text under field, icon in field border, no full-page interruption.
- **Job failure**: job status widget with error code + user-friendly message + "Retry" button.
- **Auth/consent failure**: persistent banner at top of page with specific action required.
- **API 5xx**: toast notification + ability to retry last action.

### Inline Help Pattern

- Each form section has a collapsible "ℹ️" trigger.
- Collapsed: single-line hint visible by default.
- Expanded: full explanation with a link to official docs.
- Help drawer (right panel, 360px): opens on "?" icon per step; shows contextual content from Purview docs.

### Test Console UX

```
[Left Panel]                    [Right Panel]
┌──────────────────────────┐   ┌────────────────────────────────┐
│ Select SITs              │   │ Results                        │
│ ☑ Credit Card Number     │   │ ┌──────────────────────────┐  │
│ ☑ Contoso Employee ID    │   │ │ Credit Card Number        │  │
│ □ EU Passport Number     │   │ │ High: 2 matches            │  │
│                          │   │ │ Medium: 1 match            │  │
│ Upload file or paste:    │   │ │ ────────────────────       │  │
│ ┌────────────────────┐   │   │ │ ...card ending in [####]  │  │
│ │ Drop file here     │   │   │ └──────────────────────────┘  │
│ │ or paste text      │   │   │                                │
│ └────────────────────┘   │   │ [Export results as JSON]      │
│                          │   │                                │
│ [Run Test ▶]             │   │ ● Job running... 12s           │
└──────────────────────────┘   └────────────────────────────────┘
```

### Design System Direction

**Stack:** Radix UI primitives + Tailwind CSS + custom design tokens.

**Themes:**
```typescript
// packages/design-system/src/tokens/colors.ts
export const colors = {
  // Brand
  primary: { 500: '#2563EB', 600: '#1D4ED8' },
  // Surface
  surface: { light: '#FFFFFF', dark: '#0F172A' },
  background: { light: '#F8FAFC', dark: '#020617' },
  // Status
  success: '#16A34A',
  warning: '#D97706',
  error: '#DC2626',
  info: '#0EA5E9',
  // Confidence
  high: '#16A34A',
  medium: '#D97706',
  low: '#6B7280',
};
```

**Component Categories:**
- Form: `Input`, `Textarea`, `Select`, `Combobox`, `RadioGroup`, `Switch`, `Slider` (all with label, error, hint slots)
- Layout: `PageShell`, `Sidebar`, `ContentArea`, `SplitPane`
- Navigation: `Stepper`, `Tabs`, `Breadcrumb`
- Data: `DataTable` (sortable, filterable, paginated), `VirtualList`
- Feedback: `Toast`, `Alert`, `Badge`, `StatusChip`, `ProgressBar`
- Overlays: `Dialog`, `Drawer`, `Popover`, `Tooltip`
- Special: `CodeBlock` (XML/JSON with syntax highlight, copy button), `DiffViewer`, `JobStatusPanel`, `ConfidenceBadge`

**Status Chips:**
```
[draft]      → grey outline
[ready]      → blue filled
[archived]   → grey filled
[pending]    → amber outline
[approved]   → green filled
[rejected]   → red outline
[QUEUED]     → grey + spinner
[RUNNING]    → blue + animated bar
[COMPLETED]  → green check
[FAILED]     → red X + code
[TOKEN_EXPIRED] → amber ⚠
```

**Data Tables:** virtual scroll for > 100 rows, sticky header, column resize, row click → detail drawer, bulk selection for export.

**Accessibility:** WCAG 2.1 AA. All interactive elements keyboard-navigable. ARIA labels on icon-only buttons. Focus rings visible in both themes. Color never sole indicator of state.

**Responsive:** Side navigation collapses to bottom tab bar below 768px. Wizard steps collapse to accordion on mobile. Test console stacks vertically. No mobile-only feature gating in MVP.

***

## SECTION M — API Contract Design
`spec/build-pack/v0.1/api-contract.md`

### Base

`/api/v1/` — all authenticated routes require `Authorization: Bearer {jwt}` (SaaS backend scope).

### Route Inventory

```
# AUTH / TENANT
GET    /api/v1/me
GET    /api/v1/tenants/me
POST   /api/v1/tenants/consent-complete
GET    /api/v1/tenants/me/consent-status

# SIT DRAFTS
GET    /api/v1/sits
POST   /api/v1/sits
GET    /api/v1/sits/{id}
PATCH  /api/v1/sits/{id}
DELETE /api/v1/sits/{id}
POST   /api/v1/sits/{id}/publish        # creates sit_version
GET    /api/v1/sits/{id}/versions
GET    /api/v1/sits/{id}/versions/{versionId}

# SIT PATTERNS / ELEMENTS (sub-resources, can also be inline in PATCH sit)
POST   /api/v1/sits/{id}/patterns
PATCH  /api/v1/sits/{id}/patterns/{patternId}
DELETE /api/v1/sits/{id}/patterns/{patternId}

# KEYWORD DICTIONARIES
GET    /api/v1/dictionaries
POST   /api/v1/dictionaries
GET    /api/v1/dictionaries/{id}
PATCH  /api/v1/dictionaries/{id}
DELETE /api/v1/dictionaries/{id}

# RULE PACKS
POST   /api/v1/rulepacks/import         # sync parse + validate, no job
POST   /api/v1/rulepacks/export         # sync generate XML
GET    /api/v1/rulepacks/imported       # list imported_rulepacks records
GET    /api/v1/rulepacks/imported/{id}

# JOBS (async PowerShell operations)
POST   /api/v1/jobs
GET    /api/v1/jobs/{id}
GET    /api/v1/jobs
