# HeadMouse 🎧🖱️

[![Swift](https://img.shields.io/badge/Swift-5-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014+%20|%20Apple%20Silicon-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com)
[![AirPods](https://img.shields.io/badge/AirPods-Head%20Tracking-1d1d1f?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager)
[![Privacy](https://img.shields.io/badge/Privacy-Camera--Free%20%7C%20On--Device-blueviolet?style=for-the-badge)](#-privacy)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

> **A Camera-Free, Hands-Free Head Pointer That Controls Your Mac's Cursor With the Head-Tracking Sensors in Your AirPods.**

Developed with ❤️ by **Muhittin Efecan Türk**

**English** · [Türkçe](README.md)

---

## 🌟 Overview

**HeadMouse** is a small menu bar app that reads the motion sensors inside your AirPods (gyroscope and accelerometer) and turns them into Mac cursor movement. **Turn your head** and the cursor follows. **Hold still** and a ring fills up, then it clicks. It feels like clicking with your mind.

It never uses the camera, so lighting and seating position don't matter. No data ever leaves your Mac.

```
+------------------+                                  +--------------------+
|     AirPods      | ~ ~ [ Head Motion ] ~ ~ ~ ~ ~ > |  HeadMouse (Mac)   |
|  (CoreMotion)    |     yaw / pitch / roll           |  Filters → Engine  |
+------------------+                                  +--------------------+
                                                                |
                                                   Cursor · Click · Scroll
```

> ⚠️ This is an early, experimental project. It is not a certified assistive device.

---

## 🚀 Key Features

### 1. 🎯 Precise Cursor From Tiny Movements
- **Relative (gyroscope-style) and joystick modes:** In relative mode the head's rotation *speed* drives the cursor; when you stop, it stops.
- **Pixels-per-degree speed setting:** You choose how many degrees of head turn cross the screen. The settings window shows this live.
- Acceleration, smoothing, dead zone and a separate vertical scale.
- **Hold ⇧ for precision mode:** The cursor slows down for fine work.

### 2. 🖱️ Dwell Click and Head Gestures
- **Dwell (click by waiting):** Hold the cursor still, a progress ring fills, it clicks. Duration and hold-still area are adjustable.
- **Nod / shake:** Left and right click by default. Tilting left and right can be mapped too.
- **Next-dwell type:** One shortcut makes the next dwell a right click, double click or drag. The ring color shows the type.
- Click gestures click where the cursor was *before* your head moved, so shaking your head doesn't click the wrong spot.
- Optional **smart dwell:** Only clicks on clickable items such as buttons and links.

### 3. 🛡️ Four Layers Against Idle Self-Clicking
AirPods sensors slowly "drift" over time. That drift can creep the cursor along and trigger dwell. HeadMouse guards against it with four layers:

| Layer | What it does |
| :--- | :--- |
| **Drift compensation** | Treats the speed measured while your head is still as sensor drift and keeps subtracting it |
| **Stillness filter** | Locks the cursor while the head is still; a clear nudge is needed to move again |
| **Deliberate-motion rule** | After each click, dwell re-arms only after a quick movement and enough distance |
| **Repeat-click breaker** | Suspends dwell and warns you if clicks keep repeating in the same area |

### 4. 🧩 Actions, Scrolling and Per-App Rules
- **Actions you can map to gestures:** Left / right / double click, drag lock, back (⌘[), forward (⌘]), Esc, Mission Control, switch desktop, scroll mode, pause.
- **Scroll mode:** Tilt your head up or down to scroll the page.
- **Per-app rules:** Turn HeadMouse, or just dwell, off in specific apps.

### 5. 🖥️ Full Settings Window (SwiftUI)
- 8 tabs: **General, Pointer, Click, Gestures, Scroll, Safety, Apps, Shortcuts**.
- **Live head view:** Yaw, pitch, tilt, speed and the "motion on / locked" state, in real time.
- **Test pad:** Try dwell and gestures on a grid of buttons while you tune.
- **Auto-pause** while you type, use a real mouse, or take the AirPods out.
- Global shortcuts, sound and on-screen messages, launch at login.

---

## 🏗️ Project Architecture

```
HeadMouse/
├── Info.plist                # Bundle ID, LSUIElement (menu bar app)
├── build.sh                  # Build + sign + install without Xcode
├── LICENSE
├── README.md / README.en.md
└── Sources/
    ├── main.swift            # Entry point
    ├── AppController.swift   # Menu bar, settings window, global shortcuts
    ├── Engine.swift          # Head motion → cursor, dwell, gestures, scroll, safety layers
    ├── HeadTracker.swift     # AirPods sensor reader via CMHeadphoneMotionManager
    ├── GestureDetector.swift # Nod / shake detector
    ├── Overlay.swift         # Dwell ring and on-screen message (HUD)
    ├── System.swift          # CGEvent synthesis, mouse watching, accessibility helpers
    ├── Settings.swift        # Persistent settings (ObservableObject + UserDefaults)
    ├── SettingsUI.swift      # SwiftUI settings interface
    ├── LiveState.swift       # Live state shown by the UI
    ├── Actions.swift         # Click kinds and actions mappable to gestures
    ├── HotKeys.swift         # Global shortcuts (Carbon)
    └── Math.swift            # Small helpers
```

---

## ⚙️ Motion Pipeline

| Stage | Description |
| :--- | :--- |
| **Sensor** | `CMHeadphoneMotionManager` streams yaw / pitch / roll |
| **Speed** | The *change* in angle (degrees/s) is computed; spikes (>900°/s) are dropped |
| **Drift compensation** | Readings while the head is still are removed as sensor drift |
| **Stillness gate** | The cursor stays locked unless there is enough movement |
| **Curve** | Dead zone + acceleration turn it into pixels/s |
| **Smoothing** | Sensor ~25–50 Hz, cursor ~125 Hz; in-between values are smoothed |
| **Output** | Posted as system mouse events (`CGEvent`) |

---

## 🛠️ Installation and Build

### Requirements
- **macOS:** macOS 14 (Sonoma) or later, Apple Silicon recommended
- **AirPods:** A model with head tracking: **AirPods Pro (2nd gen and later), AirPods Max, AirPods 4 with ANC**, and others with Spatial Audio head tracking. Developed on AirPods 4 (ANC) and a MacBook Air M4.
- **Xcode Command Line Tools** (full Xcode is not needed)

> Support depends on Apple's `CMHeadphoneMotionManager`. If your AirPods do not stream motion data, HeadMouse cannot work with them.

### Step by Step

1. **Clone the repo:**
   ```bash
   git clone https://github.com/muhittinefecanturk/HeadMouse.git
   cd HeadMouse
   ```

2. **Install the Command Line Tools** (if you don't have them):
   ```bash
   xcode-select --install
   ```

3. **Build and install:**
   ```bash
   ./build.sh install     # builds, copies to /Applications and launches
   ```
   *(To only build: `./build.sh`, then `open build/HeadMouse.app`.)*

4. **Grant permissions:**

   | Permission | Why |
   | :--- | :--- |
   | **Accessibility** | To move the cursor and send clicks |
   | **Motion & Fitness** | To read the AirPods head-tracking sensor |

   The **General** tab of the settings window shows what is missing and takes you to the right place. After you grant Accessibility, HeadMouse notices within a second.

5. **(Optional) Sign with your own certificate:**
   ```bash
   SIGN_ID="Apple Development: Your Name (XXXX)" ./build.sh install
   ```
   *By default the app is signed ad hoc with a fixed identifier so the Accessibility permission survives rebuilds.*

---

## 📱 Usage Guide

### First Run
1. Put your AirPods in and pick them as the Mac's **sound output**. Head data only streams while they are the output device.
2. Open the settings window from the menu bar icon or with `⌃⌥,`.
3. In **General**, check that the dot follows your head. Press **Re-center** while sitting comfortably.
4. If the cursor goes the wrong way, flip it in **Pointer → Direction**.

### Everyday Use
- **Move:** Turn your head, the cursor follows.
- **Click:** Hold still until the ring fills, or nod.
- **Right click:** Shake your head, or press `⌃⌥R` to make the next dwell a right click.
- **Scroll:** `⌃⌥S` turns on scroll mode, then tilt your head.
- **Pause:** `⌃⌥H`.

### ⌨️ Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌃⌥H` | Pause / resume |
| `⌃⌥C` | Re-center |
| `⌃⌥D` | Toggle dwell click (also resumes it if suspended) |
| `⌃⌥S` | Scroll mode |
| `⌃⌥R` / `⌃⌥F` / `⌃⌥G` | Next dwell is a right click / double click / drag |
| `⌃⌥,` | Settings |
| Hold `⇧` | Slow the cursor (precision mode) |

---

## 🎚️ Tuning Tips

- **Want to move your head less?** Raise **Pointer → Speed (pixels per degree)**.
- **Cursor drifts or clicks on its own?** Set the **Stillness filter** to Medium or High, keep drift compensation on, and lengthen the dwell time.
- **Tiny movements ignored?** Lower the stillness filter and the dead zone.
- **Too many accidental gestures?** Lower the gesture sensitivity in **Gestures**.

---

## 🩺 Troubleshooting

| Problem | Fix |
| :--- | :--- |
| "Accessibility permission required" although it is on | Remove HeadMouse from the list with **−**, run `tccutil reset Accessibility com.muhittinefecanturk.headmouse`, relaunch and allow it again |
| "Waiting for AirPods" | They must be in your ears, connected, and selected as sound output |
| Nothing moves | Check both permissions in the **General** tab |
| Cursor goes the wrong way | **Pointer → Direction** |
| Pauses on its own ("real mouse in use") | Turn that option off in **Safety**, or stop touching the trackpad |
| Left/right tilt is reversed | **Gestures → Reverse tilt direction** |

---

## 🔒 Privacy

- HeadMouse has **no network code**; it collects and sends nothing.
- Head-motion data is processed in memory on your Mac and never saved.
- Only your settings are stored, in macOS user defaults (`UserDefaults`).

---

## 🗺️ Status and Roadmap

Early version (**0.2**). It is developed and used on a single setup, so expect rough edges and please open an issue if something misbehaves.

- [ ] Calibration wizard
- [ ] Unit tests for the gesture detector
- [ ] Export / import of settings
- [ ] Horizontal scroll
- [ ] Prebuilt, notarized release

---

## 🙏 Credits

Inspired by [PodsControlMac](https://github.com/sumionochi/PodsControlMac) and by MacPaw's research on [headphone-sensed head pointing](https://research.macpaw.com/publications/headphones-accessibility). HeadMouse is an independent project and is not affiliated with Apple.

---

## 👤 Developer

**Muhittin Efecan Türk**  
*Full Stack & iOS/macOS Developer*  
- **GitHub:** [@muhittinefecanturk](https://github.com/muhittinefecanturk)

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
