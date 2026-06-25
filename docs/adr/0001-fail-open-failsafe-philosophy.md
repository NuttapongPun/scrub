# ADR-0001: Fail-open failsafe philosophy

- Status: Accepted
- Date: 2026-06-26

## Context

Scrub blocks the keyboard and trackpad while the user cleans the machine. The same
`CGEventTap` both **blocks input** and **detects the unlock chord**. This creates a
catastrophic failure mode: if the locking mechanism misbehaves, the user could be trapped
out of their own machine with no input path to recover.

The README already specifies user-facing failsafes (a reminder pop-up, a hard-unlock
timer). This ADR settles the *philosophy underneath them*: what guarantee the system makes
when the locking mechanism **itself** fails, rather than when the user merely forgets the
chord.

## Decision

**Fail-open, always.** The governing invariant is:

> If the app process is dead **or** the event tap is not active, input must flow.

Concretely:

1. The lock holds **only** while the owning process is alive *and* the tap is active.
   A process kill (`SIGKILL`) is an acceptable escape hatch: macOS removes event taps when
   their owning process exits, so a kill unblocks input for free. We rely on this rather
   than fighting it.
2. When macOS force-disables the tap (`kCGEventTapDisabledByTimeout` /
   `…ByUserInput`), Scrub treats it as a **fail-open trigger**: it un-dims, releases all
   locks, and **ends the session**, showing a brief "cleaning ended (system)" notice. It
   does **not** silently re-enable the tap and re-lock the user.

The worst realistic case under this model is an *early/unexpected unlock*, never a trapped
user. We accept weaker locking in exchange for that guarantee.

## Consequences

- Locking is explicitly **best-effort**; correctness of *unlocking* outranks reliability of
  *locking*.
- A transient system hiccup (slow tap callback under load) can end a cleaning session. This
  is acceptable and surfaced to the user. If it proves annoying in practice, revisit with a
  bounded retry (see "Considered alternatives").
- Chord detection lives inside the tap, so when the tap dies the chord dies too — but that
  is fine, because tap death already means input flows.
- Any future feature that would keep input blocked across process death or across a
  tap-disable event **contradicts this ADR** and must reopen it.

## Considered alternatives

- **Re-enable and stay locked** (README's original "auto-recover"): rejected — re-locks the
  user without warning and can oscillate if a slow callback keeps tripping the OS.
- **Re-enable with a bounded counter** (give up after N disables / window): rejected for now
  as premature; kept as the fallback if "end the session" proves too trigger-happy.
- **Fail-open + external watchdog** (launchd helper guarantees tap teardown): deferred — the
  natural CGEventTap teardown-on-exit already gives us the kill-path guarantee without a
  second moving part. Revisit only if a real zombie-tap scenario is observed.
