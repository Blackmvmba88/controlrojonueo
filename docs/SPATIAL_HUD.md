# BlackMamba Spatial HUD

## Idea

The controller should not force the user to repeatedly press a button just to advance through desktop content.

Instead, BlackMamba Controller exposes a **spatial selection layer**: move the stick and the next actionable visual target becomes the active selection. Press **A** to activate it.

The long-term goal is an augmented-reality-like desktop HUD: thumbnails, buttons, windows and media cards appear as selectable objects in a lightweight overlay while the controller moves a semantic focus rather than a raw mouse pointer.

## Interaction model

```text
Xbox controller
      ↓
gesture / button
      ↓
Spatial Navigator
      ↓
semantic intent
      ↓
visual focus target
      ↓
macOS action / app adapter / future overlay renderer
```

### MVP controls

| Input | Spatial action |
| --- | --- |
| Xbox / Mode button | Toggle Spatial HUD |
| Right stick flick → | Select next visual target |
| Right stick flick ← | Select previous visual target |
| A | Activate selected target |
| B | Exit Spatial HUD |

The stick uses hysteresis: one flick emits one navigation step and will not repeat until the stick returns near center. This prevents a held stick from flying through dozens of targets.

## Why this is different from ordinary shortcuts

A normal controller mapping says:

```text
RB = next video
```

Spatial HUD says:

```text
right-stick gesture = move semantic selection
A = activate whatever is selected
```

That distinction matters because the same navigation engine can later work over:

- YouTube/video cards
- Finder files
- browser links
- Blender tools
- DAW tracks and clips
- Mission Control windows
- BlackMamba/WARPBLACK commands

The controller stops being a bag of fixed shortcuts and becomes a physical interface for a contextual desktop.

## Phase 1 — applied in this branch

The current MVP is intentionally renderer-independent.

It implements:

1. a `SpatialNavigator` state machine;
2. right-stick flick detection with release hysteresis;
3. semantic actions `VisualPrevious`, `VisualNext` and `VisualActivate`;
4. a generic macOS focus fallback:
   - previous = Shift+Tab
   - next = Tab
   - activate = Return
5. Xbox/Mode toggles the spatial layer;
6. A activates and B exits while the layer is active.

This means the navigation core can be tested now without first committing the project to SwiftUI, Metal, AppKit, Tauri or another renderer.

## Phase 2 — real overlay

Add a transparent, click-through macOS overlay that renders the current semantic focus target.

Proposed visual language:

```text
┌──────────────────────────────────────┐
│                                      │
│      [ video 1 ]   ╔══════════╗      │
│                    ║ video 2  ║  ← selected
│      [ video 3 ]   ╚══════════╝      │
│                                      │
│   SPATIAL · CHROME · MEDIA GRID      │
└──────────────────────────────────────┘
```

The selected object can gain:

- outline/glow
- title
- action hint
- app/profile name
- controller glyph
- optional haptic confirmation

## Phase 3 — app adapters

Generic Tab focus is only the universal fallback. Native adapters should provide richer targets.

Examples:

### Browser / video

Detect visible media cards and expose their screen rectangles and metadata to the HUD.

```text
stick → next thumbnail
A     → open/play
B     → back
Y     → fullscreen
```

### Blender

```text
stick → neighboring tool/object
A     → confirm/select
B     → cancel
RT    → precision layer
```

### DAW

```text
stick → track/clip
A     → select
X     → play/pause
triggers → timeline / layer modifiers
```

## Design rule

**Input should express intent, not hard-coded keystrokes.**

The backend may currently translate an intent to Tab/Return, but the public concept remains semantic so app-specific adapters and a true overlay can replace that fallback later without changing controller behavior.

## Safety / mode behavior

Spatial HUD is desktop-only.

When AUTO mode switches to GAME:

- the spatial layer is disabled;
- pointer state is reset;
- desktop injection remains suspended;
- the game keeps ownership of the controller.

This preserves the existing GAME/DESKTOP boundary.
