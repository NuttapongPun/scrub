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
/// Un-dim is modelled as an opacity change on persistent windows, not a teardown, so a later
/// slice can reuse the same windows to host the reminder card (ADR-0005). For this slice the
/// only opacity changes are the stop-hint fade-in and the end-of-session summary fade-out.
final class DimOverlay {

    /// How long the blackout stays hint-free before the stop-hint fades in (ADR-0006: ~3–5 s).
    private static let stopHintDelay: TimeInterval = 4

    /// The stop-hint copy. CONTEXT.md is canonical: the unlock chord is **⌘ ⌥ Q** (ADR-0002's
    /// amendment). Issue #4's `a s d f j k l ;` wording predates that amendment.
    private static let stopHintText = "press ⌘ ⌥ Q to stop"

    /// How long the end-of-session total lingers on the blackout before it fades out.
    private static let summaryHold: TimeInterval = 1.6

    private var windows: [NSWindow] = []
    private var hintLabels: [NSTextField] = []
    private var revealTimer: DispatchSourceTimer?

    /// Whether the stop-hint has been revealed. Tracked separately from the labels so a
    /// mid-session display reconfiguration can rebuild the windows in the right state.
    private var hintRevealed = false

    var isActive: Bool { !windows.isEmpty }

    // MARK: - Lifecycle

    /// Blacks out every connected display and schedules the stop-hint fade-in. Idempotent.
    func start() {
        guard windows.isEmpty else { return }
        buildWindows()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        scheduleHintReveal()
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

            let label = makeHintLabel()
            label.alphaValue = hintRevealed ? 1 : 0    // preserve state across rebuilds
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
        let label = NSTextField(labelWithString: Self.stopHintText)
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.35)   // dim, not stark
        label.alignment = .center
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        return label
    }

    /// Rebuilds the blackout when the display configuration changes mid-session (a monitor is
    /// plugged in or unplugged), so every connected display stays covered. The revealed/hidden
    /// stop-hint state carries over via `hintRevealed`.
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
    }
}
