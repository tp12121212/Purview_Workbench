# User Flows v0.1

## Flow 1: Anonymous browsing
1. User lands on Home.
2. User navigates SIT Library, DLP Library, Rule Packs, Help.
3. User opens template details and docs without sign-in.
4. App never forces auth prompt during browsing-only actions.

**UX requirements**
- `Sign in` control remains visible but non-blocking.
- Protected CTAs show lock indicator and tooltip.

## Flow 2: Protected action requested while signed out
1. Anonymous user clicks protected action (e.g., `Run Test-DataClassification`).
2. Protected Action Modal appears with:
   - action requested
   - reason auth is required
   - `Sign in and continue` primary CTA
   - `Cancel` secondary CTA
3. If cancel: return to current screen with unobtrusive banner.
4. If continue: start sign-in and store `returnTo` action descriptor.

## Flow 3: Sign-in and return to requested action
1. User completes sign-in.
2. App restores previous route and pending protected intent.
3. If consent already satisfied, action becomes available for explicit re-confirmation.
4. If consent missing, transition to consent-required flow.

**Guardrail**
- Do not auto-run high-impact action immediately post-auth without visible confirmation.

## Flow 4: Consent-required state
1. Authenticated user attempts protected action.
2. Consent check indicates incomplete consent.
3. Consent Required panel/modal appears with:
   - current status
   - why required
   - `Go to Tenant Connection` CTA
4. User completes consent steps in Settings/Tenant Connection.
5. User returns to original action context.

## Flow 5: Authenticated protected test flow (mock execution)
1. Authenticated + consented user opens Test Console.
2. User configures test input and options.
3. User starts run.
4. UI shows queued → running → completed/failed state transitions (mock timeline).
5. Results panel displays deterministic mock output and status badges.

## Flow 6: Future tenant-connected flows (placeholder)
1. User visits SIT Editor or DLP Builder placeholder pages.
2. Page communicates capability roadmap and dependency on future phases.
3. Protected actions on these pages follow same auth + consent gating pattern.

## Global flow conventions
- Preserve route context through auth redirects.
- Every blocked action has a recoverable path.
- Auth, consent, and job status messages use standardized alert/badge components.
