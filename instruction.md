# Mobile touch controls for Warbird

## Objective

Warbird is a desktop browser game controlled by keyboard (and possibly
mouse). Port its gameplay inputs to a mobile touch overlay so the game is
fully playable on a phone, in both portrait and landscape orientations,
without changing how the game plays on desktop.

Concretely, you must:

1. Inventory every gameplay-essential input in the source (movement, fire /
   primary action, and any secondary actions such as pause, start, or special
   abilities).
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

- A virtual joystick for directional movement, resting on the **left** side
  of the screen (genre convention). It must support continuous drag and
  diagonal input, and return to neutral on release.
- One touch button per discrete game action (fire, secondary actions),
  grouped on the **right** side. The most frequently used action (fire) gets
  the largest button in the most comfortable spot (bottom-right, under the
  right thumb).
- Multi-touch must work: e.g. steering with the left thumb while holding
  fire with the right thumb.
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

## Output format

In addition to the working overlay, write a layout manifest to
`mobile-controls.json` at the repository root. It is the graded, reviewable
record of the layout. JSON, not XML: it is web-native, trivially parseable
by the grader, and matches the JavaScript codebase.

```json
{
  "version": 1,
  "viewports": [
    {
      "name": "compact-portrait",
      "width": 390,
      "height": 844,
      "orientation": "portrait",
      "controls": [
        {
          "id": "joystick",
          "label": "Move",
          "gameAction": "arrow-keys",
          "rect": { "x": 24, "y": 640, "width": 140, "height": 140 }
        },
        {
          "id": "btn-fire",
          "label": "Fire",
          "gameAction": "space",
          "rect": { "x": 300, "y": 700, "width": 72, "height": 72 }
        }
      ]
    }
  ]
}
```

Rules for the manifest:

- One entry per supported viewport (see matrix below), with `width`/`height`
  in CSS pixels.
- Every visible touch control appears exactly once per viewport entry, with
  its final rendered bounding box in `rect` (integers, CSS pixels relative to
  the viewport origin).
- `gameAction` names the desktop input the control replaces.
- The manifest must match the rendered overlay: the grader compares manifest
  rects against measured DOM bounding boxes.

## Viewport matrix

Device names change yearly ("iPhone 18", "Galaxy", etc.); grade by CSS-pixel
size classes instead. Support all six, i.e. three size classes in both
orientations:

| Name | Portrait (w x h) | Landscape (w x h) |
| Compact phone | 390 x 844 | 844 x 390 |
| Large phone | 430 x 932 | 932 x 430 |
| Android phone | 412 x 915 | 915 x 412 |

Landscape is the primary gaming orientation, but both must be playable: the
overlay re-lays itself out per orientation (manifest entry each), keeping
all layout rules below.

## UI layout rules (graded statically)

These are checked from the manifest and the rendered DOM at each of the six
viewports:

1. **No overlaps.** Every pair of control bounding boxes is disjoint, with
   at least a 4 px gap.
2. **On-screen.** Every control lies fully inside the viewport with at least
   an 8 px margin from each edge (safe-area clearance).
3. **Reachable touch targets.** Every control is at least 44 x 44 CSS px
   (Apple HIG / WCAG target-size floor).
4. **Thumb zones.** The joystick center sits in the left third of the screen
   and the bottom half; action buttons sit in the right third and the bottom
   half. Controls are ordered by frequency of use: the most-used action
   (fire) is closest to the bottom-right resting-thumb position and is the
   largest action button.
5. **Joystick on the left.** The movement control is a left-side joystick,
   not buttons and not on the right.
6. **Screen coverage.** The union of control bounding boxes covers at most
   25% of the viewport area, and the central playfield rectangle (centered,
   60% of width x 50% of height) contains no controls, so the overlay never
   hides the important part of the scene.
7. **Orientation fit.** All of the above hold in both portrait and landscape;
   controls may resize/reposition between orientations but must not simply
   be the portrait layout cropped or overflowing.

## Playability (graded dynamically)

With touch enabled at each of the six viewports, driven only by touch
events (tap, touchstart/move/end), the game must:

1. Start / restart from its initial screen.
2. Move in all directions via the joystick (game state or player position
   changes accordingly).
3. Trigger every discrete action via its button (e.g. projectiles fired,
   pause toggled).
4. Sustain movement and firing simultaneously (two concurrent touch points).
5. Keep `npm run check` passing (existing checks are the desktop
   no-regression gate).

## Acceptance criteria

- `npm run check` passes.
- `mobile-controls.json` exists at the repo root, validates against the
  schema above (one entry per viewport, one rect per control), and matches
  the rendered overlay within 2 px per edge.
- All seven layout rules hold at all six viewports.
- All five playability probes pass at all six viewports.
- Desktop keyboard/mouse play is unchanged.
