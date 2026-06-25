# ADR-0002: Chord detection by physical keycode, tap always watches the keyboard

- Status: Accepted
- Date: 2026-06-26

## Context

The unlock chord (default `a s d f j k l ;`) is the user's primary — and, when the keyboard
is locked, only — way to end a [cleaning session](../../CONTEXT.md). Two design questions
gate its reliability:

1. **What identity** does Scrub match on — the physical key, or the produced character?
2. **When is the keyboard tap installed** — only when the keyboard is locked, or for every
   session?

Both bear directly on [ADR-0001](0001-fail-open-failsafe-philosophy.md): the escape hatch
must not silently break.

## Decision

**1. Match by physical keycode**, not by produced character. The chord is matched against
`kVK_ANSI_A`, `_S`, `_D`, `_F`, `_J`, `_K`, `_L`, `_Semicolon` — fixed physical positions,
independent of the active keyboard layout or text input source.

**2. The event tap watches the keyboard for the entire duration of any active session**,
regardless of whether the keyboard is among the locked inputs:

- Keyboard locked → swallow key events *and* track the chord.
- Keyboard free (e.g. a trackpad-only + dim session) → pass key events through *and* still
  track the chord.

The chord is therefore the **single universal exit** from every session.

## Consequences

- A non-Latin / dead-key input source (e.g. Thai) or a Dvorak layout can never move or
  suppress the chord — the physical home-row keys are always the way out. This is the
  fail-open-consistent choice.
- The on-screen / pop-up hint shows the QWERTY legends `a s d f j k l ;` because that matches
  the **keycaps the user's fingers rest on**, which is what the keycode match tracks. (A
  non-QWERTY user pressing those physical keys still unlocks; the hint is positional.)
- One exit model for all sessions — no separate "how do I end a trackpad-only session" path
  to design, document, or test.
- Cost: the keyboard tap runs even in sessions that don't lock the keyboard. Accepted for the
  uniformity; the passive (pass-through) tap is cheap.
- Detection algorithm (informative, not binding): maintain a set of currently-held chord
  keycodes from key-down / key-up events seen by the tap; when the held set ⊇ the chord set,
  end the session. Key-repeat events are ignored for membership.

## Considered alternatives

- **Match by character**: rejected — follows the layout and can be silently broken by a Thai
  / dead-key input source mid-session, a fail-dangerous outcome.
- **Install the chord tap only when the keyboard is locked**: rejected — would require a
  second, non-chord exit path (menu bar / Esc) for keyboard-free sessions, splitting the
  exit model.
