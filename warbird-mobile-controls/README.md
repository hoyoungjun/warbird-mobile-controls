# codimango/warbird-mobile-controls

Author-facing overview for the Codimango task that adapts the open-source
[Warbird](https://github.com/jdubba1/warbird) browser game for touch-only phone
play. The solver receives the outcome-based requirements in `instruction.md`;
this README is not copied into the solver container.

## Links and status

- [Codimango task 512683](https://codimango.internalmeta.com/coding-acceleration/tasks/512683)
- [Task repository](https://github.com/codimango/warbird-mobile-controls)
- [Project and grading summary](https://docs.google.com/document/d/1vkq0c_DK6VKt_jJ2y03dVemXbvCqN-oqWjTi0Zn2vhw/edit)
- [Example touch-only gameplay video](https://drive.google.com/file/d/1-i5Ga-OoUPgCwXYT8JoxvdR3_DDiX9s9/view)

## Grading at a glance

- **Playable:** touch starts/resets the game and drives every flight action,
  fire, view, pause, multitouch, and clean release at six portrait/landscape
  phone sizes. The probe observes inputs consumed by the game, so either
  keyboard emulation or a direct touch-input channel is valid.
- **Good mobile UI:** controls are visible, practical, separated, reachable,
  accessible, responsive, visibly pressed, and kept away from central gameplay
  and HUD content without excessive screen coverage.
- **Compatible and reviewable:** rotation reflows safely, desktop play remains
  unchanged, the manifest matches rendered geometry, and each run produces six
  screenshots plus a gameplay video.

The reference, mirrored, and four-button pitch/roll designs pass all seven
tests. The untouched game passes only the two desktop-regression tests. A
deliberately poor but functional layout passes gameplay but fails only the
UI-quality test. Native test-patch validation passed both baseline and solution
phases (`2f3664d33ada41dfad5ddeade95942fa`).

## Authoring policy

Before authoring, read the [Model usage policy v2](https://codimango.internalmeta.com/tracks/t-bench#model-usage-policy) and the [Workplace v2 post](https://fb.workplace.com/groups/aaitaskquality/posts/1074223732270508). The policy page is the source of truth.

- The task seed must be human; any model may be a thought partner.
- Prompt, instruction, and model-readable task files must be human- or approved 1P-authored (no third-party model, including Codex, Claude, and Gemini, may author them).
- Tests and grading content, including assertions, rubrics, test configuration such as `tests/config.json`, fixtures, and content imported or traced by the grader, may be authored by humans, approved 1P models, or Codex with human review. Claude and Gemini remain blocked.
- Other hidden files, such as build-only environment files, orchestration, and oracle solutions, may use any model with human review.
- Reviewed first-party drafting is allowed; a human must review, own, and remain responsible for the result.
- Never forward third-party-generated findings, summaries, candidate assertions, code, briefs, recommendations, or other context into a first-party session authoring protected content.
