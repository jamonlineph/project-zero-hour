# Platforms

## Targets

| Platform | Build | Notes |
|---|---|---|
| Android phones and tablets | Android App Bundle (AAB) for Play, APK for F-Droid and GitHub | Main target. ABIs: `arm64-v8a` (devices) and `x86_64` (emulators and x86 devices) |
| **Googlebook** | Same Android build | Google's Android-based laptops (launched October 2026). Resizable desktop windows, keyboard, trackpad, mouse and game controllers |
| Chromebook | Same Android build through the Play Store | Also runs the Linux build in the Linux terminal (secondary) |
| Windows, Linux, macOS | Godot desktop exports | Testing, map making, PC players |
| Web | Godot web export | Optional demo later; not a 1.0 target |

**One Android build covers phones, tablets, Googlebooks and Chromebooks.** It must adapt to the window size and the input devices; there is no separate "laptop app".

## Godot project settings (already set in `project.godot`)

- Renderer: **Mobile** (Vulkan). Low-end devices fall back to the Compatibility (OpenGL ES 3) renderer (P1-36).
- `textures/vram_compression/import_etc2_astc=true`, so textures compress for mobile GPUs.
- `pointing/emulate_mouse_from_touch=false`. Touch and mouse are handled separately and explicitly.
- Stretch mode `canvas_items` with aspect `expand`, so the UI scales with the window. A UI-scale setting comes in P1-35.
- Orientation: sensor landscape.

## Android export (P0-11)

The owner does this once, with an agent writing the exact steps.
- Install the Android SDK and JDK 17 as described in Godot's "Exporting for Android" docs. Download Godot's export templates (Editor → Manage Export Templates).
- Create `export_presets.cfg` with an Android preset:
  - Gradle build on
  - both ABIs
  - min SDK per Godot's default
  - **target SDK 36**: Google Play has required Android 16 / API 36 for new apps and updates since 31 August 2026
  - the include filter `data/*` so the JSON content is packed
- Native libraries must support **16 KB memory pages**. Play has required this since November 2025 for apps targeting Android 15+. Use Godot's official 4.7 templates and verify with Play's pre-launch report.
- Mark the app as a game (`android:appCategory="game"`). Use landscape orientation, but allow resizing for Googlebook windows.
- Permissions: none for single-player. `INTERNET` only once multiplayer arrives.
- Signing:
  - The debug keystore is local.
  - The release upload key stays **outside the repo**; Godot keeps passwords in `.godot/export_credentials.cfg`, which is ignored.
  - Use Play App Signing.

## Googlebook specifics

- **Windows resize at any time.** Layouts use anchors and containers, the camera adapts to the aspect ratio, and nothing assumes a fixed resolution. Test in the Android Studio desktop emulator and on a real device.
- **Mouse and trackpad:**
  - Hover tooltips, right-click orders, wheel and pinch zoom.
  - Edge panning turns on after the first real mouse movement.
  - Trackpads lack a middle button, so pan with edge panning, arrow keys, or Space + drag (P1-23).
- **Keyboard:**
  - All commands have hotkeys and the hotkeys can be rebound.
  - Show shortcuts in tooltips.
  - Escape opens the menu.
- **Controllers:** optional support later (P3).
- **Focus and lifecycle:** pause single-player games when the window loses focus. Never lose a match because the laptop lid closed: autosave on pause.

## Phones

- Touch scheme: see [design/controls-and-ui.md](design/controls-and-ui.md).
- Minimum touch target: 48 dp. Keep vital buttons out of the notch and corner areas (use safe areas).
- Handle the app going to the background:
  - pause and autosave on `NOTIFICATION_APPLICATION_PAUSED`
  - resume cleanly
  - keep the screen awake during matches
- Thermal and battery care:
  - 30/60 fps cap setting
  - render-scale setting
  - battery-saver preset (P1-35)

## Performance budgets

| Tier | Example hardware | Target |
|---|---|---|
| Low | 4 GB RAM, older Mali/Adreno GPU | 30 fps, 200 units, render scale 0.75 |
| Mid | 6–8 GB RAM, recent mid-range SoC | 60 fps, 300 units |
| Googlebook / PC | laptop-class | 60+ fps, 500 units |

| Budget | Target |
|---|---|
| Sim tick | ≤ 8 ms at 300 entities (mid-range phone) |
| Draw calls | < 300 |
| Triangles on screen | < 300k |
| Memory | < 1.5 GB |
| Download size | ≤ 150 MB at 1.0 |

## Device test matrix (minimum before each phase exit)

- One low-end Android phone (Mali GPU)
- One mid-range Android phone (Adreno GPU)
- One Android tablet
- One Googlebook, or the Android Studio desktop emulator until one is available
- One Chromebook (optional)
- Windows or Linux desktop

## Distribution

| Store | Notes |
|---|---|
| **Google Play** | AAB, Play App Signing. Internal → closed → open testing tracks. Data safety form (we collect nothing), privacy policy URL, IARC content rating questionnaire |
| **F-Droid** | Built from source; needs reproducible builds and no proprietary libraries (Godot qualifies) |
| **GitHub Releases / itch.io** | APK plus desktop builds |
