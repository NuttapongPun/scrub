import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// The two states of the dead-man's-switch failsafe loop (ADR-0005). `active` is locked +
    /// (optionally) dimmed; `reminder` keeps every lock applied but lifts the dim and shows the
    /// "Still cleaning? press O+K" card while waiting for an acknowledgement.
    private enum SessionState { case active, reminder }

    private var statusItem: NSStatusItem!
    private let cleaningItem = NSMenuItem(
        title: "Start Cleaning", action: #selector(toggleCleaning), keyEquivalent: ""
    )
    private let lockKeyboardItem = NSMenuItem(
        title: "Lock Keyboard",
        action: #selector(toggleLockKeyboard), keyEquivalent: ""
    )
    private let lockPointerItem = NSMenuItem(
        title: "Lock Pointer (Trackpad & Mouse)",
        action: #selector(toggleLockPointer), keyEquivalent: ""
    )
    private let dimItem = NSMenuItem(
        title: "Dim Screen While Cleaning",
        action: #selector(toggleDim), keyEquivalent: ""
    )

    /// Persisted lock selections and failsafe timers (ADR-0007). The menu toggles write here;
    /// `startCleaning` reads it, so toggling mid-session has no effect on the running session.
    private var settings = Settings()

    private let inputBlocker = InputBlocker()
    private let dimOverlay = DimOverlay()

    /// Background timing for the running session (ADR-0006). Set at start, read once on end to
    /// show the total cleaning time; `nil` when no session is active. Never rendered live.
    private var sessionClock: SessionClock?

    /// Failsafe state for the running session (ADR-0005). The interval/grace/dim values are
    /// snapshotted at start from `settings` so a mid-session preference change can't perturb
    /// the running loop. GCD timers (not `NSTimer`) so they wake the run loop at their deadline
    /// even while the app sits idle with no input events for the full window.
    private var sessionState: SessionState = .active
    private var sessionDim = false
    private var checkInInterval: TimeInterval = 600
    private var graceInterval: TimeInterval = 300
    private var checkInTimer: DispatchSourceTimer?
    private var graceTimer: DispatchSourceTimer?

    private var isCleaning: Bool { inputBlocker.isLocked }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMenuBar()

        inputBlocker.onSessionEnd = { [weak self] reason in
            self?.handleSessionEnd(reason)
        }
        inputBlocker.onKeyActivity = { [weak self] in
            self?.dimOverlay.revealStopHint()
        }
        inputBlocker.onAckChord = { [weak self] in
            self?.acknowledgeReminder()
        }

        // ADR-0003: gate on Accessibility at launch. Untrusted → guide the user, then require
        // a relaunch. We do not live-poll within this launch.
        if !accessibilityTrusted(prompt: false) {
            promptForAccessibility()
        }
    }

    // MARK: - Menu bar

    private func setUpMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🧽"

        let menu = NSMenu()
        cleaningItem.target = self
        menu.addItem(cleaningItem)
        menu.addItem(.separator())
        lockKeyboardItem.target = self
        menu.addItem(lockKeyboardItem)
        lockPointerItem.target = self
        menu.addItem(lockPointerItem)
        dimItem.target = self
        menu.addItem(dimItem)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        )
        menu.items.last?.target = self
        statusItem.menu = menu
        updateMenu()
    }

    private func updateMenu() {
        cleaningItem.title = isCleaning ? "Stop Cleaning" : "Start Cleaning"
        lockKeyboardItem.state = settings.lockKeyboard ? .on : .off
        lockPointerItem.state = settings.lockPointer ? .on : .off
        dimItem.state = settings.dim ? .on : .off
    }

    @objc private func toggleLockKeyboard() {
        settings.lockKeyboard.toggle()
        updateMenu()
    }

    @objc private func toggleLockPointer() {
        settings.lockPointer.toggle()
        updateMenu()
    }

    @objc private func toggleDim() {
        settings.dim.toggle()
        updateMenu()
    }

    // MARK: - Cleaning session

    @objc private func toggleCleaning() {
        if isCleaning {
            // Reachable only when the pointer is *not* locked; with pointer lock on the menu
            // can't be opened, so the chord is the only exit (ADR-0004).
            inputBlocker.forceEnd(reason: .manual)
        } else {
            startCleaning()
        }
    }

    private func startCleaning() {
        // Defensive re-check (ADR-0003): the canonical gate is at launch, but a tap can't be
        // created without trust, so guide the user rather than silently failing.
        guard accessibilityTrusted(prompt: false) else {
            promptForAccessibility()
            return
        }

        guard inputBlocker.start(
            lockKeyboard: settings.lockKeyboard, lockPointer: settings.lockPointer
        ) else {
            showAlert(
                title: "Couldn't start cleaning",
                message: "Scrub couldn't install the input lock. Make sure Accessibility "
                    + "access is granted, then relaunch Scrub."
            )
            return
        }

        // Snapshot the failsafe config so a mid-session preference edit can't shift the loop.
        sessionDim = settings.dim
        checkInInterval = settings.checkInInterval
        graceInterval = settings.grace
        sessionState = .active

        // Background-only timing (ADR-0006): start the clock; the total is shown on end.
        sessionClock = SessionClock()
        if sessionDim {
            dimOverlay.start()
        }
        scheduleCheckIn()

        updateMenu()
    }

    // MARK: - Dead-man's-switch failsafe (ADR-0005)

    /// (Re)arms the check-in interval. After it elapses without any end, the session enters the
    /// reminder state and asks the user to prove they're still there.
    private func scheduleCheckIn() {
        checkInTimer?.cancel()
        checkInTimer = makeOneShotTimer(after: checkInInterval) { [weak self] in
            self?.enterReminder()
        }
    }

    /// Check-in interval elapsed: keep every lock applied, lift the dim, show the "Still
    /// cleaning? press O+K" card, and start the grace countdown to force-end (ADR-0005).
    private func enterReminder() {
        guard isCleaning, sessionState == .active else { return }
        sessionState = .reminder
        dimOverlay.enterReminder()
        graceTimer = makeOneShotTimer(after: graceInterval) { [weak self] in
            // Unacknowledged for the full grace window → force-end and unlock everything.
            self?.inputBlocker.forceEnd(reason: .forceEnd)
        }
    }

    /// O+K acknowledgement (ADR-0005): re-dim, cancel the grace countdown, and restart the
    /// check-in interval, looping indefinitely. Ignored unless a reminder is actually showing.
    private func acknowledgeReminder() {
        guard isCleaning, sessionState == .reminder else { return }
        graceTimer?.cancel()
        graceTimer = nil
        sessionState = .active
        dimOverlay.resumeActive(toDim: sessionDim)
        scheduleCheckIn()
    }

    private func handleSessionEnd(_ reason: EndReason) {
        checkInTimer?.cancel()
        checkInTimer = nil
        graceTimer?.cancel()
        graceTimer = nil
        sessionState = .active

        // Read the background timer once, on end, and show the total cleaning time (issue #5).
        let totalText = sessionClock?.totalText()
        sessionClock = nil
        updateMenu()

        if dimOverlay.isActive {
            // Surface the total on the blackout, then fade it out (ADR-0006).
            dimOverlay.finish(totalText: totalText ?? "")
        } else if let totalText {
            showTotalCleaningTime(totalText)
        }
    }

    /// A one-shot main-queue GCD timer that fires once after `seconds` and then is owned by the
    /// caller (kept alive in a property, cancelled on end). Leeway keeps it power-friendly.
    private func makeOneShotTimer(
        after seconds: TimeInterval, _ handler: @escaping () -> Void
    ) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + seconds, leeway: .milliseconds(100))
        timer.setEventHandler(handler: handler)
        timer.resume()
        return timer
    }

    /// Shows the session's total cleaning time when there's no overlay to host it (dim off).
    private func showTotalCleaningTime(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Cleaning complete"
        alert.informativeText = text
        alert.runModal()
    }

    // MARK: - Accessibility (ADR-0003)

    private func accessibilityTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func promptForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Scrub needs Accessibility access"
        alert.informativeText =
            "Scrub blocks the keyboard and trackpad while you clean, which requires "
            + "Accessibility permission.\n\nGrant access under Privacy & Security → "
            + "Accessibility, then relaunch Scrub."
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            // The system prompt both registers Scrub in the Accessibility list and opens the
            // Settings pane via its button. We deliberately don't *also* open the pane URL —
            // doing both spawns a duplicate Settings window.
            _ = accessibilityTrusted(prompt: true)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    // MARK: - Quit

    @objc private func quit() {
        // Fail-open: release input before terminating.
        inputBlocker.forceEnd(reason: .manual)
        dimOverlay.stop()   // drop the blackout at once; no summary on quit
        NSApplication.shared.terminate(nil)
    }
}
