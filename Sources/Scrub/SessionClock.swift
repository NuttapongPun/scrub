import Foundation

/// Background session timing (ADR-0006 / CONTEXT.md "Total cleaning time"): records when a
/// cleaning session starts and computes its elapsed duration. The duration is **never
/// rendered live** — it is read once, when the session ends, to surface the user the *total*
/// cleaning time ("how long did this clean take"). This type is also the natural seam for
/// session history (issue #8), which appends `{ start, duration, endedBy }` on each end.
struct SessionClock {

    /// When the session started. Captured once at `start`; elapsed time is derived on demand.
    let startedAt: Date

    init(startedAt: Date = Date()) {
        self.startedAt = startedAt
    }

    /// Elapsed time since the session started. Computed, not ticked — there is no live timer.
    func elapsed(asOf now: Date = Date()) -> TimeInterval {
        now.timeIntervalSince(startedAt)
    }

    /// The total cleaning time formatted for display on session end (e.g. "Cleaned for 2m 07s").
    func totalText(asOf now: Date = Date()) -> String {
        Self.format(elapsed(asOf: now))
    }

    /// Formats a duration as `Cleaned for <m>m <ss>s`, surfacing hours only when present so
    /// the common short clean stays terse.
    static func format(_ duration: TimeInterval) -> String {
        "Cleaned for \(compact(duration))"
    }

    /// Formats a duration compactly as `<m>m <ss>s` (or `<h>h <mm>m <ss>s` once an hour is
    /// reached), without the "Cleaned for" prefix — for history rows and aggregate totals.
    static func compact(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m \(String(format: "%02d", seconds))s"
        }
        return "\(minutes)m \(String(format: "%02d", seconds))s"
    }
}
