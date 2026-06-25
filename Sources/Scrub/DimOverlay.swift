import AppKit

/// The total-blackout dim overlay (ADR-0006 / CONTEXT.md "Dim"): one non-activating,
/// click-through black window per `NSScreen`, covering every display **including the menu bar
/// / notch**. It deliberately does not steal key focus — the event tap blocks input
/// regardless of which window is key.
///
/// The blackout starts **fully dark** with no content; after a short delay — or immediately on
/// the first key activity — a dim **stop-hint** fades in so a confused user can always find the
/// exit. There is **no live timer** (ADR-0006): elapsed time is background-only and shown as a
/// total when the session ends.
///
/// At the **reminder** stage (ADR-0005) the same windows brighten (an opacity lift, not a
/// teardown) and host the *"Still cleaning? press O + K"* card; acknowledging re-dims them.
/// A reminder can also build the windows on demand for a session that wasn't dimming, so the
/// dead-man's-switch always has somewhere to show the card.
final class DimOverlay {

    /// Active-state vs reminder-state presentation. The blackout windows persist across the
    /// transition (ADR-0006); only their opacity and the on-screen card change.
    private enum Mode { case active, reminder }

    /// How long the blackout stays hint-free before the stop-hint fades in (ADR-0006: ~3–5 s).
    private static let stopHintDelay: TimeInterval = 4

    /// The stop-hint copy. CONTEXT.md is canonical: the unlock chord is **⌘ ⌥ Q** (ADR-0002's
    /// amendment). Issue #4's `a s d f j k l ;` wording predates that amendment.
    private static let stopHintText = "press ⌘ ⌥ Q to stop"

    /// The reminder card copy (ADR-0005). Mnemonic: pressing O+K literally spells "OK".
    private static let reminderText = "Still cleaning?   press O + K to continue"

    /// Window opacity while a reminder shows: lifted off full black so the desktop glows
    /// through and the card clearly reads as "the screen woke up" (ADR-0005/0006 "brighten").
    private static let reminderWindowAlpha: CGFloat = 0.55

    /// How long the end-of-session total lingers on the blackout before it fades out.
    private static let summaryHold: TimeInterval = 1.6

    private var windows: [NSWindow] = []
    private var hintLabels: [NSTextField] = []
    private var revealTimer: DispatchSourceTimer?

    /// Current presentation. Tracked separately from the windows so a mid-session display
    /// reconfiguration rebuilds them in the right mode.
    private var mode: Mode = .active

    /// Whether the stop-hint has been revealed (active mode only). Tracked separately from the
    /// labels so a mid-session display reconfiguration can rebuild the windows in the right state.
    private var hintRevealed = false

    var isActive: Bool { !windows.isEmpty }

    // MARK: - Lifecycle

    /// Blacks out every connected display and schedules the stop-hint fade-in. Idempotent.
    func start() {
        guard windows.isEmpty else { return }
        mode = .active
        registerScreenObserver()
        buildWindows()
        scheduleHintReveal()
    }

    /// Enters the reminder presentation (ADR-0005): brighten the blackout and show the
    /// *"Still cleaning? press O + K"* card. If no overlay exists — a session that wasn't
    /// dimming — the windows are built fresh in reminder mode so the card still has a home.
    func enterReminder() {
        mode = .reminder
        revealTimer?.cancel()
        revealTimer = nil
        if windows.isEmpty {
            registerScreenObserver()
            buildWindows()
            return
        }
        for label in hintLabels { configure(label) }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5
            for window in windows { window.animator().alphaValue = Self.reminderWindowAlpha }
        }
    }

    /// Returns to the active presentation after an O+K acknowledgement (ADR-0005). When the
    /// session is dimming, re-dims to full black and restarts the stop-hint reveal; otherwise
    /// the windows existed only to host the card, so they're torn down.
    func resumeActive(toDim: Bool) {
        guard toDim else { teardown(); return }
        mode = .active
        hintRevealed = false
        for label in hintLabels { configure(label) }   // back to the hidden stop-hint
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            for window in windows { window.animator().alphaValue = 1 }
        }, completionHandler: { [weak self] in self?.scheduleHintReveal() })
    }

    /// Fades the stop-hint in across all displays. Called on the delay timer or immediately on
    /// key activity; idempotent and a no-op once revealed or after teardown.
    func revealStopHint() {
        guard isActive, !hintRevealed else { return }
        hintRevealed = true
        revealTimer?.cancel()
        revealTimer = nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            for label in hintLabels { label.animator().alphaValue = 1 }
        }
    }

    /// Shows the session's total cleaning time on the blackout, then fades the whole overlay
    /// out and tears it down (ADR-0006: a brief summary before teardown). `completion` runs
    /// after teardown. No-op (still calls `completion`) if the overlay isn't active.
    func finish(totalText: String, completion: @escaping () -> Void = {}) {
        guard isActive else { completion(); return }
        revealTimer?.cancel()
        revealTimer = nil
        hintRevealed = true

        // The summary always shows on full black, even if a reminder had brightened the windows.
        for window in windows { window.alphaValue = 1 }
        for label in hintLabels {
            label.stringValue = totalText
            label.alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.summaryHold) { [weak self] in
            guard let self, self.isActive else { completion(); return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                for window in self.windows { window.animator().alphaValue = 0 }
            }, completionHandler: {
                self.teardown()
                completion()
            })
        }
    }

    /// Tears the overlay down immediately, with no summary (used when the app is quitting).
    func stop() {
        teardown()
    }

    // MARK: - Windows

    private func buildWindows() {
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isReleasedWhenClosed = false
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.ignoresMouseEvents = true            // click-through
            // Above the menu bar / notch so the blackout is total (ADR-0006).
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [
                .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
            ]
            window.setFrame(screen.frame, display: true)
            window.alphaValue = mode == .reminder ? Self.reminderWindowAlpha : 1

            let label = makeHintLabel()
            let content = window.contentView!
            content.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            ])

            // orderFrontRegardless shows the window without activating Scrub, so the blackout
            // appears yet no window becomes key — the tap owns input regardless of focus.
            window.orderFrontRegardless()
            windows.append(window)
            hintLabels.append(label)
        }
    }

    private func makeHintLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        configure(label)
        return label
    }

    /// Sets a label's copy, styling, and visibility for the current mode. In active mode the
    /// stop-hint is dim and hidden until revealed; in reminder mode the card is bright and
    /// always shown. Called on build and on every mode transition.
    private func configure(_ label: NSTextField) {
        switch mode {
        case .active:
            label.stringValue = Self.stopHintText
            label.font = .systemFont(ofSize: 28, weight: .medium)
            label.textColor = NSColor.white.withAlphaComponent(0.35)   // dim, not stark
            label.alphaValue = hintRevealed ? 1 : 0
        case .reminder:
            label.stringValue = Self.reminderText
            label.font = .systemFont(ofSize: 34, weight: .semibold)
            label.textColor = .white
            label.alphaValue = 1
        }
    }

    private func registerScreenObserver() {
        let center = NotificationCenter.default
        let name = NSApplication.didChangeScreenParametersNotification
        center.removeObserver(self, name: name, object: nil)   // idempotent
        center.addObserver(self, selector: #selector(screensChanged), name: name, object: nil)
    }

    /// Rebuilds the blackout when the display configuration changes mid-session (a monitor is
    /// plugged in or unplugged), so every connected display stays covered. The active/reminder
    /// mode and revealed/hidden stop-hint state carry over via `mode` and `hintRevealed`.
    @objc private func screensChanged() {
        guard isActive else { return }
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        hintLabels.removeAll()
        buildWindows()
    }

    private func scheduleHintReveal() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.stopHintDelay, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in self?.revealStopHint() }
        timer.resume()
        revealTimer = timer
    }

    private func teardown() {
        revealTimer?.cancel()
        revealTimer = nil
        NotificationCenter.default.removeObserver(
            self, name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        hintLabels.removeAll()
        hintRevealed = false
        mode = .active
    }
}
