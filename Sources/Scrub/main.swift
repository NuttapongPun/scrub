import AppKit

// Scrub runs as an accessory-policy app: a menu-bar item, no Dock icon, no main window.
// See AGENTS.md and CONTEXT.md for the domain model; ADR-0001..0003 govern this milestone.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
