import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// M1 failsafe: a single hardcoded hard-unlock timer that force-ends a session no matter
    /// what (issue #2). Replaced by the configurable dead-man's-switch in a later milestone.
    private static let hardUnlockSeconds: TimeInterval = 30

    private var statusItem: NSStatusItem!
    private let cleaningItem = NSMenuItem(
        title: "Start Cleaning", action: #selector(toggleCleaning), keyEquivalent: ""
    )
    private let lockPointerItem = NSMenuItem(
        title: "Lock Pointer (Trackpad & Mouse)",
        action: #selector(toggleLockPointer), keyEquivalent: ""
    )
    private let dimItem = NSMenuItem(
        title: "Dim Screen While Cleaning",
        action: #selector(toggleDim), keyEquivalent: ""
    )

    /// Whether the next session should also lock the pointer (ADR-0004). A simple in-memory
    /// menu toggle for this slice; persistence and a configurable default land in issue #6.
    /// Read at session start, so toggling mid-session has no effect on the running session.
    private var lockPointerEnabled = false

    /// Whether the next session blacks out every display (ADR-0006). A simple in-memory menu
    /// toggle for this slice; persistence lands in issue #6. Read at session start, like
    /// `lockPointerEnabled`. Defaults on — dimming is the headline behavior.
    private var dimEnabled = true

    private let inputBlocker = InputBlocker()
    private let dimOverlay = DimOverlay()

    /// Background timing for the running session (ADR-0006). Set at start, read once on end to
    /// show the total cleaning time; `nil` when no session is active. Never rendered live.
    private var sessionClock: SessionClock?
    // A GCD timer, not an NSTimer: it wakes the run loop at its deadline on its own, so it
    // fires on time even while the app sits idle for the full window with no input events.
    private var hardUnlockTimer: DispatchSourceTimer?

    private var isCleaning: Bool { inputBlocker.isLocked }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMenuBar()

        inputBlocker.onSessionEnd = { [weak self] reason in
            self?.handleSessionEnd(reason)
        }
        inputBlocker.onKeyActivity = { [weak self] in
            self?.dimOverlay.revealStopHint()
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
        lockPointerItem.target = self
        lockPointerItem.state = lockPointerEnabled ? .on : .off
        menu.addItem(lockPointerItem)
        dimItem.target = self
        dimItem.state = dimEnabled ? .on : .off
        menu.addItem(dimItem)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        )
        menu.items.last?.target = self
        statusItem.menu = menu
    }

    private func updateMenu() {
        cleaningItem.title = isCleaning ? "Stop Cleaning" : "Start Cleaning"
        lockPointerItem.state = lockPointerEnabled ? .on : .off
        dimItem.state = dimEnabled ? .on : .off
    }

    @objc private func toggleLockPointer() {
        lockPointerEnabled.toggle()
        updateMenu()
    }

    @objc private func toggleDim() {
        dimEnabled.toggle()
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

        guard inputBlocker.start(lockPointer: lockPointerEnabled) else {
            showAlert(
                title: "Couldn't start cleaning",
                message: "Scrub couldn't install the input lock. Make sure Accessibility "
                    + "access is granted, then relaunch Scrub."
            )
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.hardUnlockSeconds, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.inputBlocker.forceEnd(reason: .forceEnd)
        }
        timer.resume()
        hardUnlockTimer = timer

        // Background-only timing (ADR-0006): start the clock; the total is shown on end.
        sessionClock = SessionClock()
        if dimEnabled {
            dimOverlay.start()
        }

        updateMenu()
    }

    private func handleSessionEnd(_ reason: EndReason) {
        hardUnlockTimer?.cancel()
        hardUnlockTimer = nil

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
