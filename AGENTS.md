# AGENTS.md

Scrub — a macOS menu-bar app for "cleaning mode" (locks keyboard/trackpad and dims the
screen while wiping the machine). See `README.md` for full scope, features, and the failsafe
design.

## Status

Planning. No source code exists yet — `README.md` is the spec. The planned layout and tech
stack live in the README; follow them when implementing.

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
