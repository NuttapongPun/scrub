# ADR-0003: Accessibility permission — prompt, then require relaunch

- Status: Accepted
- Date: 2026-06-26

## Context

Scrub cannot create its `CGEventTap` without **Accessibility** permission
(`AXIsProcessTrusted`). macOS grants this asynchronously in System Settings, and in practice
only re-reads tap eligibility reliably **after the process relaunches** — checking
`AXIsProcessTrusted()` in a tight poll within the same launch is unreliable for actually
*creating a working tap*. The app must handle the untrusted state from the first milestone,
since the tap is the core mechanism.

## Decision

On launch, if the process is **not** trusted:

1. Show an alert explaining that Scrub needs Accessibility permission to block input.
2. Open the prompt and the **Privacy & Security → Accessibility** Settings pane
   (`AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` and/or the
   `x-apple.systempreferences:` URL).
3. Tell the user to grant access and **relaunch Scrub**.

When trusted, the app proceeds normally. We do **not** attempt in-session polling to enable
features live within an untrusted launch.

## Consequences

- Costs the user one extra relaunch on first install — accepted for reliability.
- Avoids tap-permission caching bugs where a tap created mid-launch silently fails to block.
- Simple, testable launch logic: trusted → normal; untrusted → guide + exit path.
- The Start Cleaning action can still re-assert the check defensively, but the canonical gate
  is at launch.

## Considered alternatives

- **Block Start, guide + live-poll** (enable Start the instant trust flips, no relaunch):
  rejected for now — relies on same-launch tap creation working immediately after grant,
  which is the unreliable path. Reconsider if the relaunch step proves annoying and testing
  shows same-launch tap creation is dependable on target macOS versions.
- **Lazy check only at Start Cleaning**: rejected as the primary model — defers the failure to
  the moment of highest user intent and gives a worse first-run experience. (A defensive
  re-check at Start is still fine.)
