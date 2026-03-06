# Design System v0.1

## Design goals
- Professional, low-noise enterprise SaaS interface.
- High information density without visual clutter.
- Reusable primitives that support public and protected states.

## Token foundations

### Typography scale
- Font families:
  - UI: `Inter, Segoe UI, system-ui, sans-serif`
  - Mono: `JetBrains Mono, Cascadia Mono, ui-monospace, monospace`
- Sizes / line heights:
  - Display: 32/40
  - H1: 28/36
  - H2: 24/32
  - H3: 20/28
  - Title: 18/26
  - Body-lg: 16/24
  - Body: 14/22
  - Body-sm: 13/20
  - Caption: 12/18
- Weights: 400, 500, 600, 700.

### Color roles (semantic tokens)
Define role-based tokens, not hardcoded component colors.
- `bg.canvas`, `bg.surface`, `bg.surfaceElevated`
- `text.primary`, `text.secondary`, `text.muted`, `text.inverse`
- `border.default`, `border.strong`, `border.focus`
- `brand.primary`, `brand.primaryHover`, `brand.subtle`
- `state.success`, `state.warning`, `state.error`, `state.info`
- `state.*Subtle` backgrounds for alerts/badges
- `overlay.scrim`

### Light/dark theme rules
- Same semantic token names map to different values by theme.
- Dark theme must preserve contrast at equal or better readability than light.
- Data tables in dark theme need slightly elevated row separators.
- Syntax/code panels use theme-aware palette with muted background and high contrast text.

## Component standards

### Buttons
Variants:
- Primary (brand-filled)
- Secondary (neutral-filled)
- Tertiary (text/ghost)
- Destructive (error-filled)
- Protected-action CTA (same as Primary + lock icon when gated)
States:
- default, hover, active, focus-visible, disabled, loading.
Sizing:
- sm (32px), md (36px), lg (40px).

### Inputs (text)
- Label always visible.
- Optional helper and validation text.
- Prefix/suffix slot support.
- Error state uses color + icon + text.

### Textareas
- Min height 120px.
- Character count optional.
- Preserve whitespace in pasted test payload previews.

### Selects
- Support single and multi-select.
- Searchable list for template libraries.
- Chips/tags for selected filters.

### Tabs
- Underline or segmented variant.
- Must support keyboard arrow navigation.
- Use for same-page context switching only.

### Tables
- Compact and standard density modes.
- Sort indicators with clear active state.
- Empty row state embedded in table region.
- Skeleton rows for loading.

### Cards
- Use for grouped metadata and preview snippets.
- Optional status accent bar (left edge) for job/test state.

### Badges
Semantic types:
- info, success, warning, error, neutral, auth-required, consent-required.
- Include icon for auth/consent badges.

### Alerts
Levels:
- info, success, warning, error.
Structure:
- title, body, optional action, dismiss behavior.
Use:
- inline for local section messages; banner for global state changes.

### Drawers
- Right-side drawer for record details from list/table.
- Width: 480px desktop, full width mobile.
- Support compare mode in future but not required now.

### Modals
Use modals for:
- protected-action auth prompt
- consent-required explanation
- destructive confirmations
Avoid using for long-form workflows.

### Code/XML preview panels
- Monospace font.
- Line wrap toggle.
- Copy button.
- Expand/collapse.
- Show schema/version metadata header when applicable.

### Status/progress indicators
- Inline spinner for local actions.
- Page skeleton for route load.
- Stepper for consent workflow.
- Job progress chip states: queued, running, completed, failed.

### Empty states
Must include:
- concise explanation
- next best action
- optional docs link
- icon/illustration (subtle, not marketing-heavy)

### Loading states
- Prefer skeletons over indeterminate spinners for content-heavy areas.
- Keep layout stable while loading to minimize shift.

## Iconography and motion
- Use a consistent icon set with 16/20px sizes.
- Motion durations:
  - micro interactions: 120ms
  - panel transitions: 180ms
  - modal transitions: 220ms
- Respect reduced-motion settings.

## Content style rules
- Use action-first labels (`Run Classification Test`, not `Classification`).
- Keep helper text specific and procedural.
- For auth/consent notices, explain why action is blocked and exact next step.
