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
- **Build icons** are rendered by Blender (`game/assets/icons/`), with cost and hotkey overlaid by the UI.

## Accessibility (P3-20)

- UI scale slider
- Colorblind-safe team colors option
- Subtitles for voice lines
- Hold-to-confirm off/on
- Remappable keys
- Reduced camera shake
