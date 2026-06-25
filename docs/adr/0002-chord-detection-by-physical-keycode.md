# ADR-0002: Chord detection by physical keycode, tap always watches the keyboard

- Status: Accepted (amended 2026-06-26 — chord changed from a letter chord to ⌘+⌥+Q)
- Date: 2026-06-26

## Amendment (2026-06-26): chord changed to **⌘ + ⌥ + Q** due to keyboard ghosting

A multi-key *letter* chord proved **physically undetectable** on real hardware. The original
`a s d f j k l ;` are adjacent same-row keys — the worst case for keyboard **ghosting /
rollover**; the first test machine never reported more than one held at once. Moving to four
corner keys `q p z /` didn't help: the same keyboard tops out at **two simultaneous letter
keys** (the tap saw `[6, 44]` / `[35, 44]` and never three), with ghosting forcing phantom
key-ups. The rollover limit is the *count*, not the position, so no letter-only chord of 3+
keys can work on this class of keyboard.

The new default chord is **⌘ + ⌥ + Q**: hold both modifiers, then press Q. **Modifier keys
sit on dedicated matrix lines and never ghost**, and a single letter key can't exceed
rollover — so modifier-plus-one-key is reliable on any keyboard. It stays hard to trigger by
a dragged cloth (two modifiers *and* a letter at once) and is matched by physical keycode
(`kVK_ANSI_Q` = 12) plus modifier flags, preserving the layout-independence below.

This changes the matching mechanism: modifiers are read from each event's `CGEventFlags`
(always reported, never ghost) rather than tracked as a held *set* of keycodes. The
always-on-tap decision and physical-keycode principle are unchanged. On-screen hints read
`⌘ ⌥ Q`. Issue #9 (configurable chord) supersedes this hardcoded default.

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
