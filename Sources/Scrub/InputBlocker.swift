import AppKit
import os

private let log = Logger(subsystem: "com.nuttapongpun.scrub", category: "InputBlocker")

/// Why a session ended. Mirrors CONTEXT.md's `endedBy` vocabulary (`chord`, `forceEnd`,
/// `failOpen`), plus `manual` for the menu-bar Quit escape hatch. History isn't tracked in
/// M1, so this currently only drives logging and menu state.
enum EndReason {
    case chord      // user pressed the unlock chord
    case forceEnd   // failsafe force-ended (unacknowledged reminder grace, ADR-0005)
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

    /// The acknowledge ("still cleaning") chord: **hold O + K together** (`kVK_ANSI_O` = 31,
    /// `kVK_ANSI_K` = 40), the dead-man's-switch ack (ADR-0005, mnemonic "press OK"). Two
    /// letter keys is within every keyboard's rollover (ADR-0002's amendment notes at most two
    /// simultaneous letters were reliably reported), so unlike a longer letter chord this one
    /// is detectable. Matched by tracking which of these keycodes are currently held.
    private static let ackKeys: Set<CGKeyCode> = [31, 40]

    /// Called when the session ends, on the main thread. The keyboard is already released by
    /// the time this fires.
    var onSessionEnd: ((EndReason) -> Void)?

    /// Called on the main thread on each key press while locked, so the dim overlay can reveal
    /// its stop-hint immediately on key activity (ADR-0006). The keyboard stays locked — this
    /// is observation only, and the overlay de-dupes repeated calls.
    var onKeyActivity: (() -> Void)?

    /// Called on the main thread when the O+K ack chord is held (ADR-0005). Fires regardless of
    /// session state; the delegate ignores it unless a reminder is currently showing. The lock
    /// is unaffected — acknowledging keeps the machine protected and continues cleaning.
    var onAckChord: (() -> Void)?

    /// The subset of `ackKeys` physically held right now, so the ack chord fires once both are
    /// down. Cleared on `stop()`; `keyUp` removes a key even when the keyboard is locked (the
    /// event is still tapped, only swallowed after we observe it).
    private var heldAckKeys: Set<CGKeyCode> = []

    /// Whether the keyboard is being swallowed this session. The tap always watches key events
    /// — the unlock and ack chords must work even in a pointer-only or dim-only session — but
    /// when keyboard lock is off, observed key events are passed through instead of consumed.
    private var keyboardLocked = false

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

    /// Installs the tap. When `lockKeyboard` is true, keyboard input is swallowed; when
    /// `lockPointer` is true, the tap also swallows all pointer events from all devices
    /// (ADR-0004), making the chord the only exit since the menu-bar Quit becomes unreachable.
    /// The tap always *watches* the keyboard regardless, so the unlock and ack chords work even
    /// in a pointer-only or dim-only session. Returns `false` if the tap could not be created
    /// (e.g. Accessibility not granted), in which case nothing is locked.
    @discardableResult
    func start(lockKeyboard: Bool, lockPointer: Bool) -> Bool {
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

        keyboardLocked = lockKeyboard
        eventTap = tap
        runLoopSource = source
        log.info(
            "Input lock started (keyboard: \(lockKeyboard, privacy: .public), pointer: \(lockPointer, privacy: .public))"
        )
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
        keyboardLocked = false
        heldAckKeys.removeAll()
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

        if type == .keyDown {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            // Unlock chord: Q pressed while ⌘+⌥ are held. Modifiers come from the event's flags
            // (always accurate, never ghost), so there's no multi-key tracking for this one.
            if keyCode == Self.unlockKey && event.flags.contains(Self.unlockModifiers) {
                log.info("Unlock chord matched")
                DispatchQueue.main.async { [weak self] in self?.end(reason: .chord) }
            }
            // Ack chord: O and K held together (ADR-0005). Track held keycodes and fire once
            // both are down. The delegate decides whether an ack is meaningful right now.
            if Self.ackKeys.contains(keyCode) {
                heldAckKeys.insert(keyCode)
                if heldAckKeys == Self.ackKeys {
                    log.info("Ack chord matched")
                    DispatchQueue.main.async { [weak self] in self?.onAckChord?() }
                }
            }
            // Any key press is "key activity": let the overlay surface the stop-hint at once.
            DispatchQueue.main.async { [weak self] in self?.onKeyActivity?() }
        } else if type == .keyUp {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            heldAckKeys.remove(keyCode)
        }

        // Pointer locked: pin the cursor. Disassociation can lapse as events flow, so warp it
        // back to the locked position on every movement event before swallowing (ADR-0004).
        if pointerDecoupled && Self.cursorMovingTypes.contains(type) {
            CGWarpMouseCursorPosition(lockedCursorPosition)
        }

        // Pass keyboard events through when the keyboard isn't locked — the tap still watched
        // them above so the chords work, but a dim-only or pointer-only session must let the
        // user keep typing. Everything else (locked keyboard, and all tapped pointer events
        // when pointer lock is on) is swallowed.
        let isKeyEvent =
            type == .keyDown || type == .keyUp || type == .flagsChanged
        if isKeyEvent && !keyboardLocked {
            return Unmanaged.passUnretained(event)
        }
        return nil
    }

    /// Tears down and reports the end reason, on the main thread.
    private func end(reason: EndReason) {
        guard isLocked else { return }
        log.info("Keyboard lock ended: \(String(describing: reason), privacy: .public)")
        stop()
        onSessionEnd?(reason)
    }

    /// Force-ends an active session for the given reason (used by the failsafe grace timer and
    /// by the menu-bar Quit). No-op if nothing is locked.
    func forceEnd(reason: EndReason) {
        end(reason: reason)
    }
}
