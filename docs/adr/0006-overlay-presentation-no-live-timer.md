# ADR-0006: Overlay is a total blackout with a delayed stop-hint; no live timer

- Status: Accepted
- Date: 2026-06-26
- Revises: the original `README.md` ("On-screen overlay — shows a large live timer" and the
  live-timer framing of "Session timer"). The README has since been rewritten to describe the
  blackout + total-on-end behavior without a live timer.

## Context

The README described the dim overlay as hosting a **large live timer** plus a stop-hint, for
feedback while input is frozen. Two refinements changed this:

1. The user does not want a live timer on screen. Elapsed time is tracked in the
   **background** only and the **total** is shown when the session ends — that's the
   information the user actually cares about ("how long did this clean take").
2. A pure black screen with frozen input and zero instructions is the classic "am I stuck?"
   panic case, so the escape must remain discoverable.

## Decision

The overlay is a **total blackout** across every display (covers the menu bar / notch),
implemented as one non-activating, click-through window per `NSScreen` that does not steal
key focus (the tap handles input regardless of focus).

Content rules:

- **No live timer** is rendered. A background timer tracks elapsed time only.
- During the active blackout: start **fully dark**, then **fade in a dim stop-hint**
  (`press a s d f j k l ; to stop`) after ~3–5 s, or immediately on any key activity. Clean
  "screen off" look, but the escape appears right when a confused user starts pressing keys.
- At the **reminder** stage ([ADR-0005](0005-reminder-as-deadman-liveness-check.md)):
  brighten (lift opacity) and show the *"Still cleaning? press O+K"* card. The overlay is
  **not** destroyed on un-dim — un-dim is an opacity change.
- On **session end** (any cause): tear down the overlay and surface the **total cleaning
  time** to the user.

## Consequences

- Simpler overlay: no per-second label redraw; the timer is pure model state.
- "Un-dim" must be implemented as an animated opacity change on a persistent window, not a
  create/destroy, so the same window can host both the stop-hint and the reminder card.
- Total-blackout covers the menu bar, so in a session that does **not** lock the pointer the
  menu-bar exit is visually hidden — the chord remains the reliable exit
  ([ADR-0002](0002-chord-detection-by-physical-keycode.md)), consistent with treating the
  chord as universal.
- Where the "total cleaning time" is shown on end (overlay summary card vs notification vs
  menu) is **not yet decided** — see the open question; default assumption is a brief summary
  before the overlay tears down.
- Overlay work is **deferred past M1** (M1 has no dim/overlay). Requirements recorded here:
  per-`NSScreen`, non-activating, click-through, survives un-dim via opacity.

## Considered alternatives

- **Large live timer on screen** (README): rejected — the user wants the total at the end,
  not a running clock; live redraw is needless complexity.
- **Fully dark, no hint until reminder**: rejected — least safe; a user who forgets the chord
  early has no on-screen guidance for up to 10 minutes.
- **Always-visible stop-hint from t=0**: viable, but the delayed/​on-activity fade-in was
  preferred for a cleaner "screen off" feel without sacrificing discoverability.
