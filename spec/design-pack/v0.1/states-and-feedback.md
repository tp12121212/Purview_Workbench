# States and Feedback Specification v0.1

## State model overview
All main screens should implement a consistent state model:
- loading
- empty
- success
- error
- auth required
- consent required
- disabled/unavailable

Test Console additionally includes job lifecycle states:
- queued
- running
- completed
- failed

## Cross-screen state patterns

### Loading
- Use skeletons for page content regions.
- Keep headings/structure visible while body loads.
- Avoid blocking entire app shell for local loads.

### Empty
- Explain why content is empty.
- Provide exactly one primary next-step CTA.
- Optional secondary docs link.

### Success
- Use inline success toast/banner after user-triggered actions.
- Keep message specific (what succeeded and what changed).

### Error
- Present actionable guidance and retry where possible.
- Distinguish validation errors from system failures.
- Avoid exposing raw stack traces.

### Auth required
- Trigger from protected action only.
- Message must include requested action name.
- Offer `Sign in and continue` + `Cancel`.
- Preserve route and pending action state.

### Consent required
- Show when authenticated user lacks required tenant consent.
- Include current status and why consent is needed.
- Provide direct CTA to Tenant Connection screen.

### Disabled/unavailable
- Disabled controls must include tooltip/helper text.
- For not-yet-implemented features, show `Coming in future phase` badge.

## Job state visuals (Test Console)

| State | Visual treatment | User feedback |
|---|---|---|
| Queued | Neutral badge + clock icon | "Job queued. Waiting for worker slot." |
| Running | Info badge + spinner | "Classification test is running." |
| Completed | Success badge + check icon | "Run completed. Review extracted entities and matches." |
| Failed | Error badge + alert icon | "Run failed. Review error details and retry." |

## Inline help and guidance behavior
- Use contextual help text directly beneath complex controls.
- Add "Learn more" links to Help sections for advanced topics.
- In protected areas, include one-line explanation of permission requirements.
- Avoid long modal text where inline guidance is sufficient.

## Notification priorities
1. Blocking modal: auth required, destructive confirmation.
2. Inline alert: consent required, section-level errors.
3. Toast: non-blocking success and informational updates.

## Copy standards
- State messages should be imperative and specific.
- Avoid ambiguous wording like "Something went wrong" without context.
- Always provide next-step guidance for error/auth/consent states.
