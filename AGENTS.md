# AGENTS.md

Scrub — a macOS menu-bar app for "cleaning mode" (locks keyboard/trackpad and dims the
screen while wiping the machine). `README.md` is the **user-facing** product page;
`CONTEXT.md` (domain glossary) and `docs/adr/` (design decisions) are the **engineering**
source of truth.

## Status

Implemented and building. `CONTEXT.md` and `docs/adr/0001`–`0007` remain the engineering
source of truth; read those before changing behavior — they override the README where they
differ (the README describes behavior for end users, not internals).

Shipped: menu-bar app with the Accessibility launch gate (ADR-0003), `CGEventTap` keyboard
and pointer lock (ADR-0002/0004), the ⌘⌥Q unlock chord, the total-blackout dim overlay with
stop-hint (ADR-0006), the dead-man's-switch reminder + O+K acknowledgement + fail-open
force-end (ADR-0001/0005), persisted lock selections, and JSON session history (ADR-0007).

Not yet built (defaults are hardcoded): a settings UI for the unlock chord, the check-in and
grace intervals, and the dim level; launch-at-login. Distribution is ad-hoc signed — no
Developer ID signing, notarization, or Homebrew cask yet.

Layout: Swift Package Manager building a `Scrub.app` bundle via `build.sh`. `Sources/Scrub/`
holds `main.swift`, `AppDelegate.swift`, `InputBlocker.swift`, `DimOverlay.swift`,
`Settings.swift`, `SessionClock.swift`, and `SessionHistory.swift`.

## Build & run

`./build.sh` compiles with Swift Package Manager and wraps the binary into a runnable
`Scrub.app` bundle (ad-hoc signed). The app requires **Accessibility permission** to block
input and therefore cannot be sandboxed or App Store distributed.

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
