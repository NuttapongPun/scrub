# ADR-0007: Persist settings in UserDefaults, session history as JSON in Application Support

- Status: Accepted
- Date: 2026-06-26

## Context

Scrub has two kinds of state worth surviving a relaunch: **settings** (which locks are
toggled, plus the future-configurable timeouts, unlock chord, and dim level) and **session
history** (a record of past cleans, enabling the "Session history / stats" roadmap item).
They differ in stakes — settings are small key/value prefs; history is an append-only log
that needs a format, retention story, and a view.

## Decision

- **Settings → `UserDefaults`.** Selected locks (keyboard / pointer / dim), the check-in
  interval and acknowledgement-grace timeouts, the unlock chord, and the dim level live as
  `UserDefaults` keys with sensible defaults (the README defaults). Small, atomic, free to
  read at launch.
- **Session history → JSON file in Application Support.** Append one record per completed
  session: `{ start: <ISO-8601>, duration: <seconds>, endedBy: chord | forceEnd | failOpen }`.
  Stored under `~/Library/Application Support/Scrub/history.json` (or `sessions.jsonl`).
  Written on session end.
- **A menu item ("History…")** surfaces recent cleans and aggregate totals.

Capturing `endedBy` lets history also serve as a lightweight diagnostic — e.g. spotting how
often sessions force-end or fail open.

## Consequences

- Two storage mechanisms, deliberately: prefs that change rarely vs an ever-growing log.
- History needs a retention/cap decision eventually (cap entries, or prune by age) — **open
  question**, not blocking; an append-only JSON/JSONL file is fine for a personal utility for
  a long time.
- The `endedBy` field ties history to the failsafe model
  ([ADR-0005](0005-reminder-as-deadman-liveness-check.md),
  [ADR-0001](0001-fail-open-failsafe-philosophy.md)) — keep the enum in sync with the actual
  end causes.
- **Milestone ordering:** M1 persists **nothing** (hardcoded timer, no history). Settings
  persistence arrives with the real toggles/config; history persistence with the stats
  milestone. This ADR fixes the *shape* so those milestones don't redesign storage.

## Considered alternatives

- **Settings now, history later**: viable and lower-commitment, but the user wants the stats
  feature in scope; fixing the history shape now avoids a later storage redesign.
- **Persist nothing**: rejected — forces the user to re-toggle locks every launch and discards
  the cleaning-time data the app is partly *about*.
- **Core Data / SQLite for history**: rejected as overkill for an append-only personal log;
  JSON/JSONL is inspectable and trivial. Revisit only if history grows query-heavy.
