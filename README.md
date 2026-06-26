# Scrub — Mac Cleaning Mode 🧽

A tiny macOS menu-bar app that puts your Mac into **cleaning mode** — it locks the keyboard,
trackpad, and/or dims the screen so you can safely wipe the machine (or do your makeup at the
desk) without typing garbage, moving the cursor, or triggering shortcuts.

To end a session you press a **multi-key chord** — by default **⌘ + ⌥ + Q** (hold both
modifiers, then press Q). A stray swipe of a cloth can't trigger it, so wiping across
the keyboard is always safe.

---

## Why

When you clean a laptop you drag a cloth across the keys and trackpad, which types garbage,
moves the cursor, fires shortcuts, and dismisses windows. A bright screen also hides smudges.
Scrub freezes input and blacks out the display for as long as you need, tells you your total
cleaning time when you're done, then gets out of the way.

---

## Features

- **Lives in the menu bar** — no Dock icon, no windows in your way.
- **Pick what to lock** before each session:
  - Lock the **keyboard**
  - Lock the **trackpad / mouse**
  - **Black out** the screen
- **Start cleaning** — applies your locks and blacks out the screen so smudges are easy to
  see. After a moment a dim *"press `⌘ ⌥ Q` to stop"* hint fades in, so you always
  know the way out.
- **Cleaning time** — Scrub times each session and shows the **total when you finish**.
- **Safe unlock chord** — end a session only by pressing a set of keys **simultaneously**
  (default **⌘ + ⌥ + Q**). A chord, not a sequence, so partial or accidental contact
  never unlocks.
- **You can never get stuck** — see *Staying safe* below.
- **History** — review your past cleans and total time from the menu.

---

## Install

### Homebrew (recommended)

```sh
brew install --cask NuttapongPun/tap/scrub
```

Upgrade later with `brew upgrade --cask scrub`. On first launch, allow Scrub through
Gatekeeper — see [Requirements](#requirements).

### Install script

```sh
curl -fsSL https://raw.githubusercontent.com/NuttapongPun/scrub/main/install.sh | bash
```

### Manual download

Grab the latest `Scrub-vX.Y.Z.zip` from the
[Releases page](https://github.com/NuttapongPun/scrub/releases), unzip it, and move
**Scrub.app** to your Applications folder. The first time you open it, right-click
**Scrub.app → Open** and confirm.

> **First launch:** grant **Accessibility** permission when prompted so Scrub can lock
> input — see [Requirements](#requirements).

---

## How to use

1. Launch Scrub — a 🧽 icon appears in the menu bar.
2. Click it and choose what to lock (keyboard / trackpad / black out the screen). By default
   all three are on; your choices are remembered for next time.
3. Choose **Start Cleaning**. The screen goes dark and your selected input freezes.
4. Wipe away — keys and the trackpad do nothing.
5. To finish, press **`⌘ ⌥ Q` together**. Everything unlocks and Scrub shows your
   total cleaning time.

---

## The unlock chord

- **Default:** **⌘ + ⌥ + Q** — hold Command and Option, then press Q.
- It's matched by **key position**, so it works on any keyboard layout or language.
- Chosen because it's nearly impossible to trigger by dragging a cloth, but trivial to do on
  purpose — and because modifier keys never "ghost," it reliably registers on any keyboard
  (unlike multi-key letter chords, which many keyboards can't report all at once).

---

## Staying safe

You can **never** be locked out of your own Mac:

- **The "still cleaning?" check.** If a session runs long (default **10 minutes**), the
  screen brightens and asks *"Still cleaning? press `O` + `K`."* Press **O and K together** to
  keep going — the screen dims again and cleaning continues. This repeats for as long as you
  keep confirming, so even a thorough clean is never cut short.
- **Automatic unlock.** If no one confirms within a few minutes (default **5**), Scrub
  assumes you've stepped away, **unlocks everything, and ends the session** on its own.
- **Always fail-open.** If anything goes wrong — you quit Scrub, or macOS interrupts it —
  input is released immediately. Locking is always best-effort; never trapping you is the
  priority.

---

## Requirements

- macOS 11 (Big Sur) or later
- **Gatekeeper allow** — Scrub isn't notarized yet, so the first time you open it macOS
  blocks it. Right-click **Scrub.app → Open** and confirm (or allow it under **System
  Settings → Privacy & Security**). You only do this once.
- **Accessibility permission** — required so Scrub can block input. On first launch macOS
  will prompt you; grant access under **System Settings → Privacy & Security →
  Accessibility** (on macOS 12 and earlier, **System Preferences → Security & Privacy →
  Privacy → Accessibility**), then relaunch Scrub.

> Scrub is a personal-use utility. Because blocking global input requires Accessibility
> access, it is not sandboxed or distributed through the App Store.

---

## Settings

Everything lives in the menu-bar menu:

- **Choose what to lock** per session — the **keyboard**, the **trackpad / mouse**, and the
  **screen blackout**, each toggled independently. Your choices are remembered for next time.
- **History…** — review your past cleans and total cleaning time.

The unlock chord (**⌘ ⌥ Q**), the "still cleaning?" interval (**10 minutes**), and the
auto-unlock grace (**5 minutes**) currently use fixed defaults.

### Planned

- A settings screen to customize the unlock chord, the check-in interval, and the auto-unlock
  time.
- Adjust how dark the screen goes.
- Launch at login.

---

## License

Scrub is licensed under the [GNU General Public License v3.0](LICENSE). You are free to use,
modify, and redistribute it under the terms of that license; derivative works must also be
released under the GPLv3.
