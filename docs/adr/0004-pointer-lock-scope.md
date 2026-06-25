# ADR-0004: Pointer lock blocks all pointer events from all devices

- Status: Accepted
- Date: 2026-06-26

## Context

"Lock trackpad / mouse" needs a precise definition. A `CGEventTap` sees pointer events from
**all** pointing devices merged together and cannot reliably distinguish the built-in
trackpad from an external USB mouse. The events also split into classes — movement, clicks,
scroll — that could in principle be blocked selectively. Cleaning a trackpad generates all of
these (drag = movement, accidental press = clicks, two-finger wipe = scroll), so any partial
block would leak.

## Decision

When the **pointer is locked** in a session, swallow **all** pointer event classes —
`mouseMoved`, `leftMouseDragged`/`rightMouseDragged`/`otherMouseDragged`, `leftMouseDown/Up`,
`rightMouseDown/Up`, `otherMouseDown/Up`, and `scrollWheel` — from **all** pointing devices.
There is no per-device or per-class selectivity.

## Consequences

- **Pointer-locked ⇒ the unlock chord is the only exit.** The menu-bar **Quit** safety net
  disappears the moment the pointer is locked, because the user can't move or click to reach
  it. This raises the stakes on chord reliability ([ADR-0002](0002-chord-detection-by-physical-keycode.md))
  and on the reminder/hard-unlock failsafes ([ADR-0001](0001-fail-open-failsafe-philosophy.md)).
- During development, only build/test pointer-lock **after** the chord and failsafe are
  proven, since Quit is no longer reachable while it's active.
- Multi-touch **gestures/swipes** (Mission Control, etc.) partly arrive via `NSEvent` rather
  than the CGEventTap and may not be fully catchable; treat that as a known gap to document
  rather than block on.
- An external mouse cannot be exempted — locking the trackpad also freezes a plugged-in
  mouse. Accepted; matches the "freeze the surface I'm wiping" intent.
- **Swallowing `mouseMoved` does not freeze the on-screen cursor.** Consuming move events in
  the tap stops apps from *receiving* movement, but the WindowServer still glides the visible
  cursor straight from raw HID input. Pointer lock therefore also calls
  `CGAssociateMouseAndMouseCursorPosition(false)` to decouple the cursor from hardware
  movement, and re-associates on session end. This is process-scoped and auto-reset by the OS
  if Scrub dies, so it preserves fail-open ([ADR-0001](0001-fail-open-failsafe-philosophy.md)).
