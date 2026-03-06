# Information Architecture v0.1

## IA goals
- Keep first-time user experience fully explorable without sign-in.
- Distinguish **viewing public knowledge** from **performing tenant actions**.
- Preserve public shell continuity when auth/consent state changes.

## Top-level content domains
1. **Discover**: Home, How it works, Help/Docs.
2. **Libraries**: Public SIT Library, Public DLP Library, Rule Packs catalog/info.
3. **Test**: Test Console UI (publicly viewable, protected to execute).
4. **Tenant**: Settings, Tenant Connection, Consent Status (protected).
5. **Future Builders**: SIT Editor, DLP Builder placeholders.

## Public pages (anonymous allowed)
- Home / Dashboard (public overview)
- Public SIT Library
- Public DLP Library
- Rule Packs (public informational shell)
- Test Console (read/view mode)
- Help / Docs / How it works
- Future placeholders landing pages for SIT Editor and DLP Builder (read-only, clearly marked)

## Protected pages or protected sections
- Settings / Tenant Connection / Consent Status
- Tenant-specific workspace summary widgets (if shown on dashboard)
- Any page section that performs tenant read/write operations

## Protected actions
The following actions must trigger auth gating if user is anonymous:
- Upload file for Test Console execution
- Run Test-TextExtraction
- Run Test-DataClassification
- View consent status details
- Start/complete tenant connection workflow
- Sync/import/export tenant-connected artifacts
- Trigger future dictionary/rule-pack tenant operations

## Navigation model

### Primary navigation (persistent)
- Home
- SIT Library
- DLP Library
- Test Console
- Rule Packs
- Help

### Secondary navigation (contextual)
- On Test Console: Overview, Input, Detection Output, Job Timeline
- On Rule Packs: Overview, Examples, Import/Export (protected)
- On Help: Getting Started, Auth & Consent, Testing, Troubleshooting
- On Settings (protected): Tenant Connection, Consent Status, Session

## Anonymous browsing behavior
- All primary routes render without auth checks by default.
- Public data calls use public endpoints or static fixtures only.
- Protected widgets render as locked cards with “Sign in to continue” CTA.
- Anonymous users can prepare input in Test Console but cannot execute.

## Authenticated layering model
- Authentication overlays onto existing public shell; no route reset required.
- Top bar account area changes from `Sign in` CTA to user/session menu.
- Protected controls unlock in place when authenticated + consent satisfied.
- If authenticated but consent incomplete, controls remain disabled with consent guidance.

## URL and state model guidance
- Public routes stay stable regardless of auth state.
- Protected actions should include a `returnTo` descriptor:
  - route
  - action key
  - minimal payload reference
- After sign-in, app restores route and replays the protected intent only with explicit user confirmation when needed.
