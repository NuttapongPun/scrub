# Scrub — Domain Context

The shared vocabulary for Scrub. When code, issues, ADRs, tests, or UI copy name one of
these concepts, use the term exactly as defined here. Don't drift to synonyms.

## Glossary

- **Cleaning session** (a.k.a. **session**) — one run of cleaning mode: from **Start
  Cleaning** until the locks are released (by chord, by failsafe, or by a fail-open event).
  Has a start time and an elapsed duration. This is the central unit Scrub tracks.

- **Lock** — actively swallowing a class of input so it never reaches the OS. Scrub locks
  the **keyboard** and/or the **trackpad/mouse**, selected per session. "Locked" describes a
  session whose locks are currently applied. The selection (along with dim) is persisted in
  `UserDefaults` ([ADR-0007](docs/adr/0007-persistence-settings-and-session-history.md)); the
  first-run default is **everything on** — keyboard, pointer, and dim all locked.

- **Dim** — drawing a black, click-through overlay across every display (a **total
  blackout**, covering the menu bar). Separate, optional, and independent from locking (you
  can dim without locking or lock without dimming). The overlay hosts the stop-hint and
  reminder cards — but **no live timer**. See
  [ADR-0006](docs/adr/0006-overlay-presentation-no-live-timer.md).

- **Stop-hint card** — the dim `press ⌘ ⌥ Q to stop` card on the blackout. Starts
  hidden and fades in after ~3–5 s (or on key activity) for discoverability without spoiling
  the "screen off" look.

- **Total cleaning time** — the elapsed duration of a session, tracked by a background timer
  (never rendered live) and shown to the user **when the session ends**.

- **Session history** — an append-only log of completed sessions
  (`{ start, duration, endedBy }`) persisted as JSON in Application Support, surfaced via a
  "History…" menu item with aggregate totals. `endedBy` is one of `chord`, `forceEnd`,
  `failOpen`. See [ADR-0007](docs/adr/0007-persistence-settings-and-session-history.md).

- **Unlock chord** — the keys that must be held **simultaneously** to end a session (default
  **⌘ + ⌥ + Q**: hold both modifiers, then press Q). Letter-only chords ghosted on real
  keyboards; modifiers never ghost, so the chord is one letter key plus modifiers — see
  ADR-0002's amendment. A *chord*, not a sequence: partial or accidental contact never
  unlocks. Matched by **physical keycode + modifier flags** (not character), so layout/input
  source can't break it. Detected by the event tap *before* the key is swallowed, so it works even
  while the keyboard is fully locked, and it is the **universal exit** from every session.
  See [ADR-0002](docs/adr/0002-chord-detection-by-physical-keycode.md).

- **Fail-open** — the safety invariant: if the app process is dead **or** the event tap is
  inactive, input must flow. Locking is best-effort; never trapping the user is the priority.
  See [ADR-0001](docs/adr/0001-fail-open-failsafe-philosophy.md).

- **Check-in interval** — how long a session stays locked + dimmed before the reminder
  fires (default 10 min). Reset every time the user acknowledges. Configurable via
  `UserDefaults` (no settings UI yet).

- **Reminder stage** — a recurring **dead-man's-switch** liveness check (not a "forgot the
  chord" notice): at each check-in interval the screen brightens and a pop-up asks "Still
  cleaning? press O+K". The session **stays fully locked**; only the dim is lifted.
  See [ADR-0005](docs/adr/0005-reminder-as-deadman-liveness-check.md).

- **Acknowledge / OK chord** — pressing **O + K** together (mnemonic: "press OK") during the
  reminder. Means *keep cleaning*: re-dim, restart the check-in interval, loop. Distinct from
  the unlock chord (which *ends* the session). A two-key chord so a single stray key can't
  falsely keep a session locked.

- **Acknowledgement grace** — how long the reminder may stay unacknowledged before force-end
  (default 5 min). Configurable via `UserDefaults` (no settings UI yet).

- **Hard-unlock / force-end** — the last-resort failsafe: if the reminder goes unacknowledged
  for the full grace window, Scrub force-releases all locks and ends the session no matter
  what. Guarantees an absent user is never stuck.

- **Event tap** — the `CGEventTap` that both blocks input and watches for the unlock chord.
  Single point that, if it dies, triggers fail-open (it cannot block input while dead).
