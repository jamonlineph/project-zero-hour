# Controls and UI

Touch and mouse are equals: every action must be possible with either. The HUD layout is original to this project. Don't copy another game's layout.

## Mouse and keyboard (Googlebook, PC, tablets with a mouse)

| Action | Input | Status |
|---|---|---|
| Select | Left-click; Shift adds | ✅ |
| Box select | Left-drag; Shift adds | ✅ |
| Select all of a type on screen | Double-click a unit | ✅ |
| Move | Right-click ground | ✅ |
| Stop | S | ✅ |
| Pan | Arrow keys, edge of screen, middle-drag, trackpad two-finger pan gesture | ✅ |
| Pan on trackpads without a middle button | Space + drag | ✅ |
| Zoom | Wheel, pinch on trackpad, = / − | ✅ |
| Rotate camera | , and . | ✅ |
| Attack-move / hold / guard / patrol | A / H / G (then click what to guard) / Patrol button (then click the far end); right-click cancels a pending order | ✅ |
| Control groups | Ctrl+1–9 to set, 1–9 to select, double-tap to jump, Shift+1–9 to add | ✅ |
| Build menu hotkeys | Grid keys Q W E R / A S D F / Z X C V for the 12 slots of the open menu (Shift+key or right-click cancels one in production) | ✅ |
| Camera bookmarks | Ctrl+F5–F8 to save the view, F5–F8 to return to it | ✅ |
| Hover and cursor | The unit under the cursor gets a ring (red for enemies); the cursor shows select, move, attack or can't-build | ✅ |
| Menu / pause | Escape, or the Menu button (top right) | ✅ |
| Commander powers | "Commander" button (top center) opens the power tree; chosen powers get a button on the power bar next to it. Targeted powers then need a click on the map; right-click cancels | ✅ |

The keys for camera movement and unit orders can be rebound in Settings (control-group, bookmark and grid keys are fixed for now). Tooltips will show the current key.

## Touch (phones and tablets)

| Action | Gesture | Status |
|---|---|---|
| Select a unit | Tap it | ✅ |
| Move the selection | Tap the ground | ✅ |
| Pan | One-finger drag | ✅ |
| Box select | Hold still for 0.35 s, then drag | ✅ |
| Select all of a type on screen | Double-tap a unit | ✅ |
| Zoom / rotate / pan | Two fingers: pinch, twist, drag | ✅ |
| Deselect | "Clear" button in the touch bar (bottom left, above the minimap) | ✅ |
| Attack-move, stop, hold | Buttons in the command grid when units are selected | ✅ |
| LAN game (P3-14a) | Main menu, "LAN game (two devices)": one device hosts (it shows its address), the other types that address and joins; the host's menu choices (map, credits, "You" for the host, "Enemy" for the other player) set the match, and the host presses Start | ✅ |
| Computer difficulty | Easy, Normal, Hard (P3-13a: Hard thinks faster, runs more trucks and attacks sooner; no cheating) | ✅ |
| Capture (P3-08a) | Right-click or tap a neutral or enemy capturable building (oil field, solar farm, field hospital, data center) with infantry selected; the selection panel shows "capturing n%" | ✅ |
| Superweapons (P3-03) | Select your superweapon building: its button shows the charge time left, then "Launch" (tap or click the target anywhere on the map). Every player sees every superweapon's countdown under the top bar, on the right | ✅ |
| Unit abilities (P3-02f) | Buttons in the command grid's last row (for example the special forces' "Call Strike" and "Disable Building"), greyed out while cooling down; then tap or click the point or the building | ✅ |
| Control groups | Group buttons 1–5 in the touch bar: tap to select (twice quickly jumps), hold 0.5 s to store | ✅ |
| Box-select mode | "Box" toggle in the touch bar, so a one-finger drag selects instead of pans | ✅ |
| Context order | Hold a finger still for 0.6 s: a radial menu with attack-move here, move here, patrol here, stop, hold, rally here, and "guard this" when held on your own unit or building | ✅ |

## HUD layout (landscape; adapts to the window size)

```
┌──────────────────────────────────────────────────────────────┐
│ credits  power  rank ★★☆  [powers bar]              [menu]   │
│                                                              │
│                         3D battlefield                       │
│                                                              │
│ [minimap]                                 [command / build]  │
│ [groups 1-5]        [selection panel]     [3x4 button grid]  │
└──────────────────────────────────────────────────────────────┘
```

- **Phones:**
  - Minimap and command grid can collapse to edge tabs.
  - Buttons are at least 48 dp.
  - Nothing important goes in the corners where notches and rounded screens cut in.
- **Tablets and Googlebook:** everything shown at once. The layout reflows as the window is resized.
- **Build icons** are rendered by Blender (`game/assets/icons/`). Command-grid buttons (88×80) show the icon, the name and cost, and the hotkey as an amber tag in the corner.

## Look (P2-17)

- One `Theme`, built in code by `UiTheme` (`game/src/ui/ui_theme.gd`) and set on the root window; the HUD's controls get it directly because a `CanvasLayer` stops theme inheritance.
- Classic 2000s military RTS style, all original: dark olive panels and buttons with steel-olive frames, amber for hover, focus, titles and hotkeys.
- Font: **Inter** (OFL-1.1, `game/assets/fonts/`, license in `OFL.txt`): Regular for text, SemiBold for buttons, Bold for titles.
- Sizes for the 1280×720 canvas, which phones scale down: body text 18 px (16 px in dense panels, 13 px on grid buttons), buttons at least 44 px tall.
- Screenshots: `docs/screenshots/ui/`.

## Accessibility (P3-20)

- UI scale: ✅ "Interface size" (75–150%, P1-35)
- Colorblind-safe team colors: ✅ setting, Okabe-Ito palette (blue, orange, reddish purple, bluish green), also on the minimap (P3-20)
- Remappable keys: ✅ (P1-35)
- Subtitles for voice lines: when voice lines exist (there are none yet; acknowledgements are radio chirps)
- Hold-to-confirm off/on: when a destructive command exists (there is no sell button yet)
- Reduced camera shake: when camera shake exists (there is none yet)
