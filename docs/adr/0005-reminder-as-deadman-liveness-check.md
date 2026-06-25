# ADR-0005: Reminder stage is a recurring dead-man's-switch, acknowledged by an O+K chord

- Status: Accepted
- Date: 2026-06-26
- Supersedes: the original failsafe timeline in `README.md` ("Auto-unlock failsafe" /
  "Failsafe timeline"). The README has since been rewritten as user-facing docs that describe
  this dead-man's loop ("Staying safe" section).

## Context

The README framed the failsafe as a one-shot: at 10 min the screen brightens and shows a
"you forgot the chord" pop-up while staying locked; at +5 min it hard-unlocks. But
[ADR-0004](0004-pointer-lock-scope.md) established that a pointer-locked session is
**chord-only** — so merely brightening the screen at 10 min gives the user no *new* way out,
and the one-shot framing assumes the user simply forgot rather than asking whether anyone is
still there.

A better model treats the reminder as a **liveness check** (dead-man's switch): periodically
ask "are you still cleaning?" If yes, continue; if no one answers, end the session. This
guarantees the user is never stuck *and* supports genuinely long cleans.

## Decision

The failsafe is a recurring liveness loop with two configurable timers (defaults below):

- **Check-in interval** (default **10 min**): time a session stays locked + dimmed before a
  reminder fires.
- **Acknowledgement grace** (default **5 min**): how long the reminder pop-up may stay
  unacknowledged before Scrub force-ends the session.

State machine:

```
            Start Cleaning
                 │
                 ▼
        ┌──────────────────┐  unlock chord (a s d f j k l ;) ──▶ end (user)
        │     ACTIVE        │  fail-open event (ADR-0001) ───────▶ end (system)
        │ locked + dimmed   │
        └──────────────────┘
                 │ check-in interval elapses (10 min)
                 ▼
        ┌──────────────────┐  O+K chord ──▶ ACTIVE (re-dim, restart interval) ── loop
        │    REMINDER       │  unlock chord ──▶ end (user)
        │ locked, UN-dimmed │  fail-open event ──▶ end (system)
        │ "Still cleaning?  │
        │  press O+K" pop-up│  grace elapses (5 min, no O+K) ──▶ HARD-UNLOCK ──▶ end
        └──────────────────┘
```

Key rules:

1. During the **reminder**, the session **stays fully locked** (keyboard + pointer as
   configured); only the dim is lifted so the pop-up is readable. Input is *not* released —
   the cloth is assumed still on the keys.
2. **Acknowledge = press the O+K chord** (physical keycodes `kVK_ANSI_O` + `kVK_ANSI_K` held
   together), matched by the same tap that watches the unlock chord. Mnemonic: literally
   "press **OK**." On ack → re-dim, restart the check-in interval, cancel the grace timer,
   loop indefinitely.
3. **Force-end** fires only if the reminder is unacknowledged for the full grace window. This
   is the hard backstop: with no one present to press O+K, the session always ends.
4. The **unlock chord** ends the session at any time, in either state.
5. No absolute session ceiling: a present user may keep cleaning indefinitely by
   acknowledging each interval. Accepted, because each ack requires a deliberate two-key
   chord that a single stray key cannot trigger.

## Consequences

- The reminder is no longer "you forgot the chord"; it is "prove you're still here." This is
  strictly safer — an absent user always gets force-ended.
- **Two chords** for the user to learn: unlock (`a s d f j k l ;` = *end*) and ack (`O+K` =
  *continue*). The mnemonic keeps the ack memorable.
- Residual risk: `O` and `K` are physically close, so a cloth could in principle hold the ack
  chord and keep a session alive. Two keys held simultaneously is far less likely than one,
  and the unlock chord remains available; accepted. Revisit if false-acks are observed (e.g.
  require a farther-apart ack chord).
- `README.md`'s failsafe section is now stale and must be revised to describe the dead-man's
  loop, the O+K ack, and the "force-end only on unacknowledged grace" rule.
- Both timers are configurable (already on the README roadmap); the loop semantics are the
  fixed part.
- **Deferred to a later milestone** — M1 keeps a single hardcoded short hard-unlock timer
  (per the M1 spec) and does **not** implement the reminder loop.

## Considered alternatives

- **README one-shot** (brighten + pop-up, hard-unlock at +5): rejected — gives no new exit at
  the reminder for pointer-locked sessions and assumes "forgot" rather than "absent."
- **Release input during the ack window**: rejected — the user wanted the machine to stay
  protected while cleaning continues; releasing locks mid-clean would let the cloth act.
- **Simple-key ack with an absolute session ceiling**: rejected — a stray key could falsely
  acknowledge; the deliberate O+K chord removes that failure mode without needing a ceiling.
