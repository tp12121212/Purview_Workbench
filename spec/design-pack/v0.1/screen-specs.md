# Screen Specifications v0.1

## 1) Home / Dashboard (`/`)
- **Purpose**: orient users, surface public capabilities, and expose protected tenant entry points.
- **Target user**: new evaluators, authenticated operators.
- **Sections**:
  1. Hero/value strip with quick actions.
  2. KPI cards (mock usage and template counts).
  3. Recent public templates section.
  4. Tenant status card group (locked when anonymous).
- **Components**: page header, cards, badges, table/list preview, alerts.
- **Key actions**:
  - Browse SIT Library (public)
  - Browse DLP Library (public)
  - Go to Test Console (public)
  - Open Tenant Connection (protected)
- **Empty states**: if no recent templates, show “Explore libraries” CTA.
- **Loading/error**: skeleton card row + inline alert for data load failure.
- **Mock vs real**:
  - mock: KPI values, recent templates
  - future real: tenant health and usage telemetry
- **Public vs protected**:
  - public: all summary browsing sections
  - protected: tenant status details and management CTAs

## 2) Public SIT Library (`/sit-library`)
- **Purpose**: provide discoverable SIT templates and examples.
- **Target user**: policy authors and evaluators.
- **Sections**:
  1. Filter/search toolbar.
  2. Result table/card grid.
  3. Detail drawer with pattern summary and sample text.
- **Components**: search input, filter chips/selects, table, drawer, badges.
- **Key actions**:
  - filter by category/region/confidence
  - open template detail
  - copy sample pattern (public)
  - import to tenant (protected placeholder)
- **States**:
  - empty search results message with reset filter CTA
  - table skeleton loading
  - inline error alert
- **Mock vs real**:
  - mock: template list and details
  - future real: community/public DB feed
- **Public vs protected**:
  - public: browse/filter/details
  - protected: import/clone to tenant workspace

## 3) Public DLP Library (`/dlp-library`)
- **Purpose**: show DLP template packs and workload examples.
- **Target user**: compliance admins and security engineers.
- **Sections**:
  1. Filter controls (workload, severity, mode).
  2. Template list table.
  3. Rule summary panel/drawer.
- **Components**: badges (workload), table, tabs, drawer, alerts.
- **Key actions**:
  - browse and inspect policies
  - view sample conditions/actions
  - import template (protected placeholder)
- **States**:
  - empty filter state guidance
  - loading skeleton rows
  - recoverable error with retry
- **Mock vs real**:
  - mock: policy/rule examples
  - future real: canonical template service
- **Public vs protected**:
  - public: all browsing
  - protected: tenant import/sync

## 4) Test Console (`/test-console`)
- **Purpose**: central test harness shell for extraction/classification workflow.
- **Target user**: policy testers.
- **Sections**:
  1. Input pane (sample text/file metadata placeholder).
  2. Configuration pane (test type and options).
  3. Action bar with protected run buttons.
  4. Results pane (structured output).
  5. Job timeline pane.
- **Components**: textareas, selects, buttons, code preview panel, status chips, timeline list.
- **Key actions**:
  - prepare input (public)
  - run extraction/classification (protected)
  - inspect output details (public if mock data available)
- **States**:
  - auth-required modal on run when anonymous
  - consent-required panel when auth incomplete
  - queued/running/completed/failed job visuals
  - empty result state before first run
- **Mock vs real**:
  - mock: full execution lifecycle and result payload
  - future real: job id from protected API and worker-backed results
- **Public vs protected**:
  - public: UI exploration and input preparation
  - protected: execution actions

## 5) Rule Packs (`/rule-packs`)
- **Purpose**: explain XML rule-pack artifacts and offer examples.
- **Target user**: admins needing import/export literacy.
- **Sections**:
  1. Concept overview.
  2. Example pack list.
  3. XML preview panel.
  4. Protected tenant operations panel.
- **Components**: cards, code/XML panel, table/list, alerts, buttons.
- **Key actions**:
  - browse examples
  - copy XML snippet
  - import/export tenant rule pack (protected placeholder)
- **States**:
  - no examples available state
  - preview loading fallback
  - structured parse error display for invalid sample
- **Mock vs real**:
  - mock: example packs and XML snippets
  - future real: tenant import/export operations
- **Public vs protected**:
  - public: learning and viewing examples
  - protected: tenant-bound import/export

## 6) Help / Docs / How it works (`/help`)
- **Purpose**: explain product behavior and workflows.
- **Target user**: all users.
- **Sections**:
  1. Quickstart blocks.
  2. Auth and consent explainer.
  3. Testing workflow docs.
  4. Troubleshooting FAQ.
- **Components**: article cards, anchor nav, callouts.
- **Key actions**:
  - jump to section
  - open linked screens
- **States**: static content loading and fallback message if docs fail to load.
- **Mock vs real**:
  - mock: all content
  - future real: docs CMS optional
- **Public vs protected**: fully public.

## 7) Settings / Tenant Connection / Consent Status (`/settings/*`)
- **Purpose**: manage tenant-scoped auth and consent visibility.
- **Target user**: authenticated tenant admins/operators.
- **Sections**:
  1. Tenant connection summary.
  2. Consent status timeline.
  3. Session details.
- **Components**: status cards, stepper, alerts, action buttons.
- **Key actions**:
  - start consent flow
  - refresh status
  - return to pending protected task
- **States**:
  - auth required route guard
  - consent pending/incomplete/complete states
  - error with remediation guidance
- **Mock vs real**:
  - mock: status data
  - future real: protected status endpoints
- **Public vs protected**: fully protected.

## 8) Future placeholders (`/sit-editor`, `/dlp-builder`)
- **Purpose**: communicate roadmap and future capabilities without implementing them.
- **Target user**: users exploring advanced authoring.
- **Sections**:
  1. Capability preview.
  2. Planned workflow stages.
  3. Dependencies and current status.
- **Components**: roadmap cards, badges, links to current libraries.
- **Key actions**:
  - browse related templates
  - subscribe/watch updates (optional placeholder)
- **States**: always static placeholder in this phase.
- **Mock vs real**: mock-only.
- **Public vs protected**:
  - public: roadmap content
  - protected: any “start authoring” CTA should gate and then show not-yet-available notice
