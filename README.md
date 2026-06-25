# Scrub — Mac Cleaning Mode 🧽

> **Scrub** is the app name; "Mac Cleaning Mode" is the descriptive tagline used for the repo
> title, website, and search. In the UI (menu bar, About) the app is just **Scrub**.

A tiny macOS menu-bar app that puts your Mac into a **cleaning mode** — it locks the
keyboard, trackpad, and/or dims the screen so you can safely wipe the machine (or do your
makeup at the desk) without triggering anything. It also tracks how long each cleaning
session takes.

To end a session, you press a **multi-key chord** (default `asdfjkl;` — all 8 keys at
once). A single accidental key press won't unlock it, so wiping across the keyboard is safe.

> Status: **planning** — this README defines the scope. Implementation has not started yet.

---

## Why

When you clean a laptop you drag a cloth across the keys and trackpad, which types garbage,
moves the cursor, triggers shortcuts, and can dismiss windows. Cleaning the screen while it's
bright also makes smudges hard to see. Scrub freezes input and dims the display for the
duration, then gets out of the way.

---

## Features

- **Menu-bar app** — lives in the macOS menu bar, no Dock icon, no main window.
- **Pick what to lock** before each session, via checkmark toggles:
  - Lock **keyboard**
  - Lock **trackpad / mouse**
  - **Dim** the screen
- **Start cleaning** — applies the selected locks and begins the session.
- **On-screen overlay** — shows a large live timer and the "how to stop" hint, so you get
  feedback even while input is frozen.
- **Session timer** — tracks elapsed cleaning time; shows total when you finish.
- **Safe unlock chord** — end the session only by pressing a configured set of keys
  simultaneously (default `a s d f j k l ;`). Prevents accidental unlocks while wiping.
- **Auto-unlock failsafe** — so you can never get stuck if you forget the chord:
  - At a timeout (default **10 min**) the screen **brightens back to normal** and a
    pop-up appears reminding you which keys to press to unlock.
  - If the session is *still* locked a while after that (default **+5 min**), Scrub
    **hard-unlocks automatically** and ends the session as a last resort.

---

## How it works (high level)

| Capability | Mechanism |
|---|---|
| Block keyboard + trackpad | A `CGEventTap` intercepts input events and swallows them while locked. |
| Detect the unlock chord | The same tap watches key-down/up and tracks which keys are held; when **all** chord keys are down at once, the session ends. |
| Dim the screen | A black, click-through overlay window is drawn across every display. The overlay also hosts the timer + stop-hint card. |
| Track time | A 1-second timer updates the overlay and the menu-bar title. |
| Auto-unlock failsafe | Two scheduled timers: a **reminder** timer (un-dims + shows the unlock pop-up) and a **hard-unlock** timer (force-ends the session). Both reset when a session starts. |

Because the event tap sees keys *before* swallowing them, the unlock chord works even while
the keyboard is fully locked.

### Failsafe timeline

```
Start ──────────────▶ 10 min ─────────────▶ 15 min
 locked & dimmed      brighten + show        hard auto-unlock
                      "press a s d f j k l ;"  (session ends)
                      pop-up; still locked     no matter what
```

The reminder stage handles the common case — *you forgot the chord* — by making the screen
visible again and telling you exactly which keys to press, without ending your session. The
hard-unlock stage is the absolute backstop in case anything (even chord detection) goes wrong.

---

## Requirements

- macOS 13 (Ventura) or later
- Xcode / Swift toolchain (Swift 6.x)
- **Accessibility permission** — required for the app to block input. macOS will prompt on
  first run; grant it under **System Settings → Privacy & Security → Accessibility**.

> Note: Scrub cannot be sandboxed / App Store distributed, because blocking global input
> requires Accessibility access. This is intended as a personal-use utility.

---

## Tech stack

- **Language:** Swift
- **UI:** AppKit (`NSStatusItem` menu bar + borderless `NSWindow` overlay)
- **Input control:** Core Graphics `CGEventTap`
- **Permissions:** ApplicationServices (`AXIsProcessTrusted`)
- **Build:** Swift Package Manager, wrapped into a `Scrub.app` bundle

---

## Usage (planned)

1. Launch Scrub — a 🧽 icon appears in the menu bar.
2. Click it and toggle what you want to lock (keyboard / trackpad / dim screen).
3. Choose **Start Cleaning**.
4. The screen dims and a timer appears. Wipe away — keys and trackpad do nothing.
5. To finish, press **`a s d f j k l ;` together**. Locks release and the total time is shown.

---

## The unlock chord

- Default: `a s d f j k l ;` — the 8 home-row keys, pressed simultaneously.
- Chosen because it's nearly impossible to trigger by dragging a cloth, but trivial to do
  on purpose with two hands.
- Rationale: a chord (not a sequence) means partial/accidental contact never unlocks.

---

## Safety considerations

- If both keyboard and trackpad are locked, the chord is the primary way out — so the chord
  detection must be rock-solid, **and** the auto-unlock failsafe (above) guarantees you are
  never permanently stuck even if you forget the chord or detection fails.
- The event tap auto-recovers if macOS disables it (timeout), so it can't silently leave you
  stuck.

---

## Project layout (planned)

```
makeup-macbook/
├── README.md
├── Package.swift
├── Info.plist
├── build.sh                # builds Scrub.app and ad-hoc signs it
└── Sources/
    └── Scrub/
        ├── main.swift          # app entry, accessory activation policy
        ├── AppDelegate.swift   # menu bar, toggles, session orchestration
        ├── InputBlocker.swift  # CGEventTap + chord detection
        └── DimOverlay.swift    # dim windows + timer/hint card
```

---

## Roadmap / ideas

- [ ] Configurable unlock chord
- [ ] Configurable failsafe timeouts (reminder / hard-unlock)
- [ ] Session history / total cleaning time stats
- [ ] Adjustable dim level
- [ ] Launch at login
