import Foundation

/// Persisted user settings (ADR-0007, settings half). The per-session lock selections plus the
/// failsafe timers live as `UserDefaults` keys with the documented defaults, so they survive
/// relaunch. Reads are free at launch; this type is also the scaffold for future config keys
/// (unlock chord, dim level) — add a `Key` and an accessor. Session *history* (the other half
/// of ADR-0007) is a separate, later concern and intentionally not modelled here.
struct Settings {

    private enum Key {
        static let lockKeyboard = "lockKeyboard"
        static let lockPointer = "lockPointer"
        static let dim = "dim"
        static let checkInInterval = "checkInIntervalSeconds"
        static let grace = "ackGraceSeconds"
    }

    /// First-run defaults: lock everything — keyboard, pointer, and dim all on (the safest,
    /// most complete "cleaning mode"); check-in 10 min, acknowledgement grace 5 min (ADR-0005).
    /// Registered, not written, so an unset key reads its default without persisting until the
    /// user toggles it.
    static let registeredDefaults: [String: Any] = [
        Key.lockKeyboard: true,
        Key.lockPointer: true,
        Key.dim: true,
        Key.checkInInterval: 600.0,
        Key.grace: 300.0,
    ]

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        store.register(defaults: Self.registeredDefaults)
    }

    var lockKeyboard: Bool {
        get { store.bool(forKey: Key.lockKeyboard) }
        set { store.set(newValue, forKey: Key.lockKeyboard) }
    }

    var lockPointer: Bool {
        get { store.bool(forKey: Key.lockPointer) }
        set { store.set(newValue, forKey: Key.lockPointer) }
    }

    var dim: Bool {
        get { store.bool(forKey: Key.dim) }
        set { store.set(newValue, forKey: Key.dim) }
    }

    /// Locked + dimmed time before the dead-man's-switch reminder fires (ADR-0005).
    var checkInInterval: TimeInterval {
        get { store.double(forKey: Key.checkInInterval) }
        set { store.set(newValue, forKey: Key.checkInInterval) }
    }

    /// How long an unacknowledged reminder may linger before Scrub force-ends the session.
    var grace: TimeInterval {
        get { store.double(forKey: Key.grace) }
        set { store.set(newValue, forKey: Key.grace) }
    }
}
