import AppKit
import os

private let log = Logger(subsystem: "com.nuttapongpun.scrub", category: "InputBlocker")

/// Why a session ended. Mirrors CONTEXT.md's `endedBy` vocabulary (`chord`, `forceEnd`,
/// `failOpen`), plus `manual` for the menu-bar Quit escape hatch. History isn't tracked in
/// M1, so this currently only drives logging and menu state.
enum EndReason {
    case chord      // user pressed the unlock chord
    case forceEnd   // hard-unlock timer fired
    case failOpen   // OS force-disabled the tap (ADR-0001)
    case manual     // app is quitting
}

/// Installs a `CGEventTap` that swallows keyboard input while tracking the physical keycodes
/// currently held, and ends the session when the unlock chord is held. Fail-open is the
/// governing invariant (ADR-0001): the lock holds *only* while this process is alive and the
/// tap is active; any OS-forced disable ends the session rather than re-locking.
final class InputBlocker {

    /// The unlock chord: **hold ⌘ + ⌥ and press Q** (`kVK_ANSI_Q` = 12). Matched by physical
    /// keycode + modifier flags so layout/input source can't break it (ADR-0002).
    ///
    /// Multi-key *letter* chords proved physically undetectable: real keyboards ghost — the
    /// tested machine reported at most two of the home-row/corner keys held at once. Modifier
    /// keys sit on dedicated matrix lines and never ghost, and a single letter key can't
    /// exceed rollover, so modifier + one key is reliable on any keyboard. See ADR-0002's
    /// amendment.
    private static let unlockKey: CGKeyCode = 12
    private static let unlockModifiers: CGEventFlags = [.maskCommand, .maskAlternate]

    /// Called when the session ends, on the main thread. The keyboard is already released by
    /// the time this fires.
    var onSessionEnd: ((EndReason) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Whether this session locked the pointer, so `stop()` knows to re-associate the cursor.
    /// Swallowing `mouseMoved` stops apps from *receiving* movement but the WindowServer still
    /// glides the visible cursor from raw HID input. Disassociating the cursor alone is flaky
    /// (events flowing through the tap can silently re-associate it), so we *also* warp the
    /// cursor back to `lockedCursorPosition` on every movement event — see `handle`.
    private var pointerDecoupled = false

    /// Where the cursor is pinned while the pointer is locked, in global display coordinates
    /// (top-left origin, matching `CGEvent.location` / `CGWarpMouseCursorPosition`).
    private var lockedCursorPosition: CGPoint = .zero

    /// Movement event types that visibly drag the cursor and so must be warped back when the
    /// pointer is locked. Clicks and scroll don't move the cursor, so they only need swallowing.
    private static let cursorMovingTypes: Set<CGEventType> = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
    ]

    /// App Nap throttles an accessory app's timers and defers its main-queue work, which makes
    /// the hard-unlock timer fire late and the chord-unlock dispatch lag. Hold a latency-
    /// critical activity assertion for the lifetime of a session to keep both prompt.
    private var activity: NSObjectProtocol?

    var isLocked: Bool { eventTap != nil }

    /// All pointer event classes the tap must swallow when the pointer is locked. The tap
    /// can't distinguish the built-in trackpad from an external mouse, nor is any class
    /// exempted — wiping a trackpad produces movement, clicks, and scroll alike (ADR-0004).
    private static let pointerEventTypes: [CGEventType] = [
        .mouseMoved,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp,
        .scrollWheel,
    ]

    /// Installs the tap and begins swallowing keyboard input. When `lockPointer` is true, the
    /// tap also swallows all pointer events from all devices (ADR-0004); the unlock chord is
    /// then the only exit, since the menu-bar Quit becomes unreachable. Returns `false` if the
    /// tap could not be created (e.g. Accessibility not granted), in which case nothing is
    /// locked.
    @discardableResult
    func start(lockPointer: Bool) -> Bool {
        guard eventTap == nil else { return true }

        var mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        if lockPointer {
            for type in Self.pointerEventTypes {
                mask |= (1 << type.rawValue)
            }
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let blocker = Unmanaged<InputBlocker>.fromOpaque(refcon!).takeUnretainedValue()
                return blocker.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "Scrub cleaning session active"
        )

        if lockPointer {
            // Freeze the visible cursor: consuming move events isn't enough, the WindowServer
            // still moves the cursor from raw HID input (ADR-0004). Pin it where it is now and
            // both decouple it from hardware and warp it back on every move (see `handle`).
            lockedCursorPosition = CGEvent(source: nil)?.location ?? .zero
            CGAssociateMouseAndMouseCursorPosition(0)
            pointerDecoupled = true
        }

        eventTap = tap
        runLoopSource = source
        log.info("Input lock started (pointer locked: \(lockPointer, privacy: .public))")
        return true
    }

    /// Releases the keyboard and tears down the tap. Idempotent. Does **not** invoke
    /// `onSessionEnd`; the caller owns session-end semantics.
    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if pointerDecoupled {
            CGAssociateMouseAndMouseCursorPosition(1)
            pointerDecoupled = false
        }
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    // MARK: - Tap callback

    /// Handles one tapped event. Returns `nil` to swallow it, or the event to pass it through.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // ADR-0001: an OS-forced disable is a fail-open trigger — end the session, never
        // silently re-enable and re-lock.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { [weak self] in self?.end(reason: .failOpen) }
            return nil
        }

        // Unlock chord: Q pressed while ⌘+⌥ are held. Modifiers are read from the event's
        // flags (always reported accurately, never ghost), so there's no multi-key tracking.
        if type == .keyDown {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if keyCode == Self.unlockKey && event.flags.contains(Self.unlockModifiers) {
                log.info("Unlock chord matched")
                DispatchQueue.main.async { [weak self] in self?.end(reason: .chord) }
            }
        }

        // Pointer locked: pin the cursor. Disassociation can lapse as events flow, so warp it
        // back to the locked position on every movement event before swallowing (ADR-0004).
        if pointerDecoupled && Self.cursorMovingTypes.contains(type) {
            CGWarpMouseCursorPosition(lockedCursorPosition)
        }

        // Input is locked: swallow every tapped event — every key event, and (when pointer
        // lock is on) every pointer event in `pointerEventTypes` (ADR-0004).
        return nil
    }

    /// Tears down and reports the end reason, on the main thread.
    private func end(reason: EndReason) {
        guard isLocked else { return }
        log.info("Keyboard lock ended: \(String(describing: reason), privacy: .public)")
        stop()
        onSessionEnd?(reason)
    }

    /// Force-ends an active session for the given reason (used by the hard-unlock timer and
    /// by the menu-bar Quit). No-op if nothing is locked.
    func forceEnd(reason: EndReason) {
        end(reason: reason)
    }
}
