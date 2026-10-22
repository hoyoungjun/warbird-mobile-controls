# Mobile touch controls for Warbird

## Objective

Warbird is a desktop browser game controlled by keyboard (and possibly
mouse). Port its gameplay inputs to a mobile touch overlay so the game is
fully playable on a phone, in both portrait and landscape orientations,
without changing how the game plays on desktop.

Concretely, you must:

1. Inspect the game source and inventory every gameplay-essential input
   yourself. Do not assume the set of controls; discover it from the code.
2. Implement an on-screen touch overlay that exposes a touch equivalent for
   each of those inputs.
3. Emit a machine-readable layout manifest describing the overlay geometry
   (see "Output format").
4. Keep the game playable end-to-end by touch alone ("test play it"): start
   the game, move, and use every action using only touch events.

## Repository and environment

- Repository: `https://github.com/jdubba1/warbird`, base commit
  `251d6d85cbe5eedbebf7625a8df7fd2430f8d1a1`, checked out at `/app`.
  Language: JavaScript.
- Run the repo's own check with `npm run check`. It must still pass when you
  are done.
- Verification runs headless Chromium (Playwright is available at
  `/opt/mobile-test`) with touch enabled and the network disabled. Do not
  add runtime dependencies and do not rely on any network resource at play
  time.

## What to build

- Inspect the source to determine which inputs matter for gameplay. Every
  existing bound keyboard command discovered in the source needs a touch
  equivalent, including flight/movement inputs, the primary action,
  camera/view, reset/restart, and pause/menu commands. Discover the actual
  mappings from the code; do not assume the set of controls.
- Provide a virtual joystick for directional movement, on the **left** side
  of the screen. It must support continuous drag and diagonal input, and
  return to neutral on release.
- Provide touch buttons for the discrete game actions, on the **right** side
  of the screen.
- Multi-touch must work: steering and using actions at the same time must be
  possible.
- Touch input must drive the **same code path** as the existing keyboard
  input (synthesize the same events or call the same handlers), not a
  parallel reimplementation of game logic.
- The overlay must not break desktop play: with a mouse/keyboard and a
  desktop-size viewport, the game behaves exactly as before. Touch controls
  appear only on touch-capable viewports (pointer: coarse / touch detection).
- Prevent mobile browser interference: `touch-action: none` on controls, a
  suitable `viewport` meta tag, no page scroll/zoom while playing.
- Prefer adding new files for the overlay; keep edits to existing game logic
  to minimal wiring.
- You decide the exact coordinates, spacing, sizing, grouping, visual
  priority, and orientation-specific composition. The left/right placement
  above is the only directional guidance.

## Output format

In addition to the working overlay, write a layout manifest to
`mobile-controls.json` at the repository root. It is the graded, reviewable
record of the layout, in JSON.

Serialization contract (exact keys, no extra keys at any level):

- The top-level object must have exactly `version` and `viewports`, with `version` equal to 1.
- Each viewport object in `viewports` must use exactly `name`, `width`,
  `height`, `orientation`, and `controls`.
- Each control object in `controls` must use exactly `id`, `label`, `gameAction`,
  and `rect`.
- `rect` must use exactly integer CSS-pixel `x`, `y`, `width`, and `height`,
  relative to the viewport origin.

Schema shape (placeholder type names only, not layout values):

```json
{
  "version": 1,
  "viewports": [
    {
      "name": "String",
      "width": "Integer",
      "height": "Integer",
      "orientation": "String",
      "controls": [
        {
          "id": "String",
          "label": "String",
          "gameAction": "String",
          "rect": {
            "x": "Integer",
            "y": "Integer",
            "width": "Integer",
            "height": "Integer"
          }
        }
      ]
    }
  ]
}
```

`gameAction` identifies which existing desktop input the control drives. The
agent chooses all coordinates, sizes, spacing, grouping, visual priority,
and orientation composition; the manifest only records the chosen final
rendered bounding boxes.

Rules for the manifest:

- One entry per supported viewport (see matrix below).
- Every visible touch control appears exactly once per viewport entry, with
  its final rendered bounding box.
- The manifest must truthfully match the rendered overlay: reported boxes
  must correspond to the measured DOM bounding boxes of the controls.

## Viewport matrix

Device names change yearly; grade by CSS-pixel size classes instead. These
dimensions are compatibility inputs your overlay must support, not layout
answers. Support all six, i.e. three size classes in both orientations.
Each entry in `viewports` must use exactly the listed `name` string for its
dimensions:

| `name` | width x height | Orientation |
| `compact-portrait` | 390 x 844 | portrait |
| `compact-landscape` | 844 x 390 | landscape |
| `large-portrait` | 430 x 932 | portrait |
| `large-landscape` | 932 x 430 | landscape |
| `android-portrait` | 412 x 915 | portrait |
| `android-landscape` | 915 x 412 | landscape |

Landscape is the primary gaming orientation, but both must be playable: the
overlay re-lays itself out per orientation, with one manifest entry per
viewport.

## Layout expectations

There is no single correct coordinate layout. Work out a layout that plays
well at each of the six viewports, meeting these outcomes:

- Comfortable for two-thumb play, with movement on the left and actions on
  the right.
- Controls are practically tappable, fully visible, and non-overlapping.
- The overlay stays responsive across viewports and orientations.
- Gameplay and HUD elements stay readable; the overlay avoids unnecessarily
  obscuring them.

Evaluation uses broad usability guardrails plus functional playtesting, not
comparison against one golden coordinate layout.

## Playability (graded dynamically)

With touch enabled at each of the six viewports, driven only by touch
events (tap, touchstart/move/end), the game must:

1. Start / restart from its initial screen.
2. Move in all directions via the joystick (game state or player position
   changes accordingly).
3. Trigger every discrete action via its button.
4. Sustain movement and action use simultaneously (two concurrent touch
   points).
5. Keep `npm run check` passing (existing checks are the desktop
   no-regression gate).

## Acceptance criteria

- `npm run check` passes.
- `mobile-controls.json` exists at the repo root, validates against the
  schema above (one entry per viewport, one box per control), and matches
  the rendered overlay.
- The layout expectations hold at all six viewports.
- All playability probes pass at all six viewports.
- Desktop keyboard/mouse play is unchanged.
