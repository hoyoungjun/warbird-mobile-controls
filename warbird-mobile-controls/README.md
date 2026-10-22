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

The reference implementation passes all seven required grader tests. The
untouched game passes only the two desktop-regression tests, and a deliberately
poor but functional mobile layout fails the dedicated UI-quality check. Hidden
grading exercises touch-only play across six portrait and landscape phone
viewports, responsive layout quality, multitouch/release behavior, rotation,
desktop compatibility, screenshots, and a gameplay recording. It intentionally
does not prescribe the model's control design or exact layout: mirrored and
four-button pitch/roll alternatives also pass all seven tests.

## Authoring policy

Before authoring, read the [Model usage policy v2](https://codimango.internalmeta.com/tracks/t-bench#model-usage-policy) and the [Workplace v2 post](https://fb.workplace.com/groups/aaitaskquality/posts/1074223732270508). The policy page is the source of truth.

- The task seed must be human; any model may be a thought partner.
- Prompt, instruction, and model-readable task files must be human- or approved 1P-authored (no third-party model, including Codex, Claude, and Gemini, may author them).
- Tests and grading content, including assertions, rubrics, test configuration such as `tests/config.json`, fixtures, and content imported or traced by the grader, may be authored by humans, approved 1P models, or Codex with human review. Claude and Gemini remain blocked.
- Other hidden files, such as build-only environment files, orchestration, and oracle solutions, may use any model with human review.
- Reviewed first-party drafting is allowed; a human must review, own, and remain responsible for the result.
- Never forward third-party-generated findings, summaries, candidate assertions, code, briefs, recommendations, or other context into a first-party session authoring protected content.
