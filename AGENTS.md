# AGENTS.md

## Source of truth
Treat `spec/build-pack/v0.1/build-pack-v0.1.md` as the current authoritative design source unless a newer file explicitly supersedes it.

## Working rules
- Do not invent or replace major architecture decisions.
- Follow the documented auth model, worker model, data model, API contract, and repo structure.
- If the spec is missing something important or contains contradictions, stop and propose a spec patch instead of guessing.
- Keep changes scoped to the requested phase only.
- Prefer minimal, reviewable diffs.
- Add tests and validation scaffolding where practical.
- Do not redesign the system into app-only auth, local agents, browser-side PowerShell, or customer-side app registration.

## Phase control
Only implement the phase explicitly requested in the task prompt.

## Validation
- Run lint/typecheck/tests where possible.
- Show created files and explain any deviations from the spec.