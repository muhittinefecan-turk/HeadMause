<div align="center">

# HeadMouse

**Control your Mac's cursor with your AirPods. Just move your head. Hold still to click.**

A hands-free, camera-free head pointer for macOS, built on the motion sensors inside your AirPods.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-ready-black)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)

[English](README.md) · [Türkçe](README.tr.md)

</div>

<!-- Add a screenshot of the settings window and uncomment:
<p align="center"><img src="docs/settings.png" width="760" alt="HeadMouse settings window"></p>
-->

## What is it?

HeadMouse is a small menu bar app that turns the head-tracking sensors in your AirPods into a mouse:

- **Turn your head** and the cursor follows. A few degrees of movement can cross the whole screen.
- **Hold the cursor still** and a ring fills up, then it clicks. It feels like clicking with your mind.
- **Nod** for a left click, **shake your head** for a right click, or map your own actions to head gestures.

No camera, no lighting problems, no cloud. Everything runs on your Mac.

It is built for people who want to try hands-free input, and it can also help anyone who has trouble using a mouse or trackpad. It is an early, experimental project, not a certified assistive device.

## Features

**Pointer**
- Relative (gyroscope-style) and joystick modes
- Pixels-per-degree speed setting, so you choose how little you need to move
- Acceleration, smoothing, dead zone, separate vertical scale
- **Drift compensation** and a **stillness filter**, so the cursor stays put when you do
- Hold ⇧ to slow the cursor for precise work

**Clicking**
- **Dwell click** with a progress ring: hold still to click
- Dwell only arms after a deliberate movement, so it never clicks by itself while you sit still
- Repeat-click breaker that suspends dwell if it starts to misbehave
- "Next dwell is a right / double click / drag" with one shortcut
- Optional smart dwell that only clicks on buttons and links

**Head gestures**
- Nod, shake, tilt left, tilt right, each mapped to an action of your choice
- Actions: left, right and double click, drag lock, back, forward, Esc, Mission Control, switch desktop, scroll mode, pause, and more
- Click gestures click where the cursor was *before* your head moved

**More**
- Head-tilt scroll mode
- Per-app rules: turn HeadMouse or dwell off in specific apps
- Live head-motion view and a test pad in the settings window
- Pauses automatically while you type or use a real mouse, and when you take the AirPods out
- Menu bar app with global shortcuts

## Requirements

- A Mac running **macOS 14 (Sonoma) or later**
- AirPods with head tracking: **AirPods Pro (2nd gen and later), AirPods Max, AirPods 4 with ANC**, and other models that support Spatial Audio head tracking. Developed on AirPods 4 (ANC) and a MacBook Air M4.
- Xcode Command Line Tools (full Xcode is not needed)

> Support depends on Apple's `CMHeadphoneMotionManager`. If your AirPods do not stream motion data, HeadMouse cannot work with them.

## Install

```bash
xcode-select --install       # once, if you don't have the Command Line Tools
git clone https://github.com/<your-username>/HeadMouse.git
cd HeadMouse
./build.sh install           # builds, copies to /Applications and launches
```

Just build without installing: `./build.sh`, then `open build/HeadMouse.app`.

### Permissions

HeadMouse asks for two permissions. Both stay on your Mac.

| Permission | Why |
|---|---|
| **Accessibility** | To move the cursor and send clicks |
| **Motion & Fitness** | To read the AirPods head-tracking sensor |

The **General** tab of the settings window shows what is missing and takes you to the right place. After granting Accessibility, HeadMouse picks it up within a second.

If you build it yourself, the app is signed ad hoc with a fixed identifier so the Accessibility permission survives rebuilds. To sign with your own certificate, run `SIGN_ID="Apple Development: Your Name (XXXX)" ./build.sh`.

## Using it

1. Put your AirPods in and select them as the Mac's **sound output**. Head data is only streamed while they are connected as the output device.
2. Open the menu bar icon, or press `⌃⌥,`, to open the settings window.
3. In **General**, check that the dot follows your head. Press **Re-center** while sitting comfortably.
4. Turn your head to move the cursor. Hold still to click, nod to left-click.
5. If the cursor moves the wrong way, flip it in **Pointer → Direction**.

### Shortcuts

| Shortcut | Action |
|---|---|
| `⌃⌥H` | Pause / resume |
| `⌃⌥C` | Re-center |
| `⌃⌥D` | Toggle dwell click (also resumes it if suspended) |
| `⌃⌥S` | Toggle scroll mode |
| `⌃⌥R` / `⌃⌥F` / `⌃⌥G` | Next dwell is a right click / double click / drag |
| `⌃⌥,` | Open settings |
| Hold `⇧` | Slow the cursor (precision mode) |

## Tuning tips

- **Want to move your head less?** Raise **Pointer → Speed (pixels per degree)**. The slider shows how many degrees it takes to cross your screen.
- **Cursor drifts or clicks on its own?** Set the **Stillness filter** to Medium or High, keep drift compensation on, and lengthen the dwell time.
- **Tiny movements are ignored?** Lower the stillness filter and the dead zone.
- **Too many accidental gestures?** Lower the gesture sensitivity in **Gestures**.

## How it works

1. `CMHeadphoneMotionManager` streams yaw, pitch and roll from the AirPods.
2. The engine takes the *change* in angle (degrees per second), removes the sensor's slow drift, applies a stillness gate, a dead zone and an acceleration curve, and turns it into cursor velocity.
3. Velocity is smoothed and posted at up to 125 Hz as system mouse events (`CGEvent`).
4. Dwell, gestures and scroll mode run on top. A gesture detector finds nods and shakes in the angle signal, and only counts them if your head was still just before.

Source layout: `Sources/` holds `HeadTracker`, `Engine`, `GestureDetector`, `Overlay` (ring and on-screen messages), `System` (events, accessibility helpers), `Settings` and `SettingsUI` (SwiftUI).

## Troubleshooting

| Problem | Fix |
|---|---|
| "Accessibility permission required" although it is on | Remove HeadMouse from the Accessibility list with **−**, then run `tccutil reset Accessibility com.muhittinefecanturk.headmouse`, relaunch and allow it again |
| "Waiting for AirPods" | They must be in your ears, connected, and selected as sound output |
| Nothing moves | Check both permissions in the **General** tab |
| Cursor goes the wrong way | **Pointer → Direction** |
| Pauses on its own ("real mouse in use") | Turn that option off in **Safety**, or stop touching the trackpad |
| Left/right tilt is reversed | **Gestures → Reverse tilt direction** |

## Privacy

HeadMouse has no network code, collects nothing, and stores only your settings in macOS user defaults. Head-motion data is processed in memory on your Mac and is never saved or sent anywhere.

## Status and roadmap

Early version (0.2). It is developed and used on one setup, so expect rough edges and please open an issue if something misbehaves.

- [ ] Calibration wizard
- [ ] Export / import of settings
- [ ] Horizontal scroll
- [ ] Prebuilt, notarized release

## Credits

Inspired by [PodsControlMac](https://github.com/sumionochi/PodsControlMac) and by MacPaw's research on [headphone-sensed head pointing](https://research.macpaw.com/publications/headphones-accessibility). HeadMouse is an independent project and is not affiliated with Apple.

## License

[MIT](LICENSE)
