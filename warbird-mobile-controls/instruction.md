# Mobile touch controls for Warbird

## Objective

Warbird is a desktop browser game controlled by desktop inputs (keyboard
and possibly mouse). Make it fully playable by touch on phones, in both
portrait and landscape orientations, without regressing desktop play.

Concretely, you must:

1. Inspect the game source and inventory every gameplay-essential desktop
   input yourself. Do not assume the set of inputs; discover it from the
   code.
2. Implement an on-screen touch overlay that exposes a touch equivalent for
   each of those inputs.
3. Emit a machine-readable layout manifest describing the overlay geometry
   (see "Output format").
4. Keep the game playable end-to-end by touch alone: start/restart the game
   and exercise every source-discovered input using only touch.

You must determine the input inventory, control types, mappings, placement,
sizing, grouping, visual priority, and orientation-specific composition from
the source and UX needs.

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
  gameplay-essential desktop input discovered in the source needs a touch
  equivalent. Do not assume the set of inputs.
- Touch alone must suffice for full play, including starting/restarting from
  the initial screen and exercising every source-discovered input.
- Simultaneous controls must work where gameplay requires it: multiple
  concurrent touch contacts must each take effect.
- Releasing a control must end its input cleanly, with no stuck or lingering
  input.
- The overlay must avoid browser gesture interference while playing: game
  touches must not cause page scroll, zoom, or navigation.
- The overlay must preserve desktop behavior: with a mouse/keyboard and a
  desktop-size viewport, the game behaves exactly as before, and touch
  controls do not interfere.
- You decide the input inventory, control types, mappings, placement, sizing,
  grouping, visual priority, and orientation-specific composition. There is
  no prescribed control set or arrangement beyond the outcomes in this
  prompt.

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

`gameAction` identifies which existing desktop input the control drives. You
determine the input inventory, control types, mappings, placement, sizing,
grouping, visual priority, and orientation-specific composition; the manifest
only records the chosen final rendered bounding boxes.

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

Both orientations must be fully playable: the overlay adapts per
orientation, with one manifest entry per viewport.

## Layout expectations

There is no single correct coordinate layout. Work out a layout that plays
well at each of the six viewports, meeting these outcomes:

- Controls are practical and reachable by touch, fully visible, and
  non-overlapping, with nothing placed offscreen.
- The overlay stays responsive across viewports and orientations.
- Gameplay and HUD elements stay readable; the overlay avoids obscuring
  important game/HUD content.

Evaluation uses broad usability guardrails plus dynamic playtesting, not
comparison against one golden coordinate layout.

## Playability (graded dynamically)

With touch enabled at each of the six viewports, driven only by touch
input, the game must:

1. Start / restart from its initial screen.
2. Exercise every source-discovered gameplay input (game state changes
   accordingly).
3. Sustain simultaneous controls where gameplay requires it (multiple
   concurrent touch contacts).
4. Release cleanly: ending a touch ends its input, with no stuck input and
   no page scroll/zoom.
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
