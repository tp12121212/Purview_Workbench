# Layout System v0.1

## App shell structure

### Desktop (>= 1200px)
- Top bar: full width, fixed, 64px height.
- Sidebar: fixed left rail, 240px width (collapsible to 72px).
- Content region: fluid, max content width 1440px centered within available area.
- Content padding: 24px horizontal / 24px vertical.

### Tablet (768px–1199px)
- Top bar: fixed, 60px height.
- Sidebar: overlay drawer triggered by hamburger.
- Content padding: 20px horizontal / 20px vertical.

### Mobile (< 768px)
- Top bar: fixed, 56px height.
- Navigation: bottom sheet or overlay menu.
- Content padding: 16px horizontal / 16px vertical.
- Tables default to card-list fallback pattern.

## Page composition rules
1. Use `PageHeader` section first: title, subtitle, primary action, optional secondary action.
2. Follow with `KPI/summary row` for dashboard-like pages.
3. Main content organized as 12-column responsive grid.
4. Avoid more than 3 nested card levels.
5. Keep action controls near affected content.

## Grid and spacing rhythm
- Base spacing token: 4px.
- Standard increments: 4/8/12/16/20/24/32/40/48.
- Grid gutter: 16px (mobile), 20px (tablet), 24px (desktop).
- Section vertical spacing: 24px default, 32px for major blocks.

## Max widths
- Standard content max width: 1280px.
- Wide analytical pages max width: 1440px.
- Reading/doc pages max width: 960px.
- Modal max widths:
  - Small: 480px
  - Medium: 720px
  - Large: 960px

## Core layout patterns

### Card pattern
- Card padding: 16px (compact) or 24px (standard).
- Header + body + optional footer actions.
- Use for KPIs, summaries, guidance panels, and preview snippets.

### Grid pattern
- KPI row: 4-up desktop, 2-up tablet, 1-up mobile.
- Template cards: 3-up desktop, 2-up tablet, 1-up mobile.

### Table pattern
- Sticky header.
- Optional sticky first column for long identifiers.
- Toolbar with search, filter, and sort.
- Row action menu for secondary operations.

### Split panel pattern (Test Console)
- Left pane: input and controls.
- Right pane: results and timeline.
- Collapses to stacked sections on tablet/mobile.

## Responsive behavior standards
- Navigation labels truncate gracefully when sidebar collapsed.
- Long XML/code blocks use horizontal scrolling inside bounded panels.
- CTAs remain visible via sticky action bar on small screens when forms are long.
- No content should require viewport widths > 320px.

## Accessibility and usability layout rules
- Maintain visible focus rings for keyboard navigation.
- Minimum interactive target: 40x40px.
- Contrast ratio: WCAG AA minimum.
- Avoid relying on color alone for status semantics.
