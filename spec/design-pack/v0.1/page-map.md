# Page Map v0.1

## Route catalog

| Route | Name | Access | Primary purpose | Notes |
|---|---|---|---|---|
| `/` | Home / Dashboard | Public | Product overview, quick start, status summaries | Includes public stats and protected tenant cards |
| `/sit-library` | Public SIT Library | Public | Browse SIT templates and examples | Filter/search/table + detail drawer |
| `/dlp-library` | Public DLP Library | Public | Browse DLP templates and examples | Workload badges, severity and mode tags |
| `/test-console` | Test Console | Public shell, protected execute | Prepare test input and inspect mock outputs | Execute actions gated |
| `/rule-packs` | Rule Packs | Public info, protected tenant ops | Explain rule-pack model and show examples | Import/export CTA protected |
| `/help` | Help / Docs / How it works | Public | User education and workflow guidance | Includes auth/consent FAQ |
| `/settings` | Settings index | Protected | Tenant-scoped settings entry point | Redirect to sign-in if deep-linked anonymously |
| `/settings/tenant` | Tenant Connection | Protected | Show tenant connection and consent status | Consent initiation CTA |
| `/settings/consent` | Consent Status | Protected | Explain consent requirements and state | Read-only status + resolve steps |
| `/sit-editor` | SIT Editor (placeholder) | Public placeholder | Future builder preview and roadmap | No authoring in this phase |
| `/dlp-builder` | DLP Builder (placeholder) | Public placeholder | Future builder preview and roadmap | No authoring in this phase |

## Screen hierarchy
- **Global shell**
  - Top bar
  - Sidebar/primary nav
  - Content area
- **Page templates**
  - Overview pages: dashboard-style cards + tables
  - Library pages: filter rail + result table/grid
  - Console page: form + results + timeline
  - Docs page: article list + content pane

## Deep-linking rules
- Public deep links are always accessible.
- Protected deep links should present auth gate and preserve `returnTo`.
- If user cancels auth gate, remain on current public shell with non-destructive notice.

## Future placeholder treatment
For `/sit-editor` and `/dlp-builder`:
- Display a structured placeholder page with:
  - intended capability summary
  - planned modules
  - dependencies on future phases
  - CTA to browse current template libraries
- No hidden feature flags that imply implementation readiness.
