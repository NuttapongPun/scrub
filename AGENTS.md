# AGENTS.md

Scrub — a macOS menu-bar app for "cleaning mode" (locks keyboard/trackpad and dims the
screen while wiping the machine). `README.md` is the **user-facing** product page;
`CONTEXT.md` (domain glossary) and `docs/adr/` (design decisions) are the **engineering**
source of truth.

## Status

Pre-implementation. No source code exists yet. The design is settled in `CONTEXT.md` and
`docs/adr/0001`–`0007`; read those before implementing — they override the README where they
differ (the README describes behavior for end users, not internals). First milestone (M1):
menu-bar app, Accessibility launch gate, `CGEventTap` keyboard lock, keycode unlock chord,
and a single hardcoded fail-open hard-unlock timer — no dim, settings, or history yet.

Planned layout (per the README's original tech notes): Swift Package Manager building a
`Scrub.app` bundle, with `Sources/Scrub/` split into `main.swift`, `AppDelegate.swift`,
`InputBlocker.swift`, and `DimOverlay.swift`.

## Build & run

Built with Swift Package Manager and wrapped into a `Scrub.app` bundle (planned `build.sh`).
The app requires **Accessibility permission** to block input and therefore cannot be
sandboxed or App Store distributed.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) for all commit messages
(e.g. `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`github.com/NuttapongPun/scrub`, via the `gh` CLI). External PRs are **not** a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary — `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
