# codimango-parser-version: 2
# ============================================================================
#                          PARSER.PY — OUTPUT CONTRACT
# ============================================================================
# THIS SCRIPT'S JSON OUTPUT IS A CONTRACT. MSL's grader reads exactly this
# shape; any deviation produces SILENT MIS-GRADES.
#
# Required output (written to argv[3]):
#
#     {
#       "tests": [
#         {"name": "<test_id>", "status": "PASSED|FAILED|SKIPPED|ERROR"},
#         ...
#       ]
#     }
#
# Rules (all must hold):
#   1. Top-level key MUST be "tests"; value MUST be a list of dicts.
#   2. Each entry MUST have string keys "name" and "status".
#   3. "status" MUST be exactly one of: PASSED, FAILED, SKIPPED, ERROR.
#   4. "name" MUST string-equal the corresponding entry in config.json's
#      FAIL_TO_PASS / PASS_TO_PASS. No trailing whitespace, no ANSI codes.
#   5. Every name in FAIL_TO_PASS ∪ PASS_TO_PASS MUST appear in the output.
#      Missing tests are silently treated as "not passing".
#
# The validate_contract() call at the bottom of main() enforces rules 1-3 and
# will EXIT NON-ZERO with a loud banner if the parser violates the shape. Do
# NOT silence or remove this check — it is the primary signal that the parser
# has a bug.
# ============================================================================

import dataclasses
import json
import re
import sys
from enum import Enum
from pathlib import Path
from typing import List


class TestStatus(Enum):
    PASSED = 1
    FAILED = 2
    SKIPPED = 3
    ERROR = 4


@dataclasses.dataclass
class TestResult:
    name: str
    status: TestStatus


### DO NOT MODIFY THE CODE ABOVE ###
### Implement the parsing logic below ###


# Pytest states a result in several different orders, and all have to be read:
#
#   verbose   nacl/tests/test_x.py::Klass::test_y FAILED               [ 50%]
#   summary   FAILED nacl/tests/test_x.py::Klass::test_y - AssertionError
#   xdist     [gw0] [ 50%] FAILED nacl/tests/test_x.py::Klass::test_y
#   subtest   SUBFAILED(i=3) nacl/tests/test_x.py::Klass::test_y - AssertionError
#   subtest   (i=3) SUBFAIL nacl/tests/test_x.py::Klass::test_y
#   subtest   nacl/tests/test_x.py::Klass::test_y (i=3) SUBFAIL        [ 50%]
#
# The last three are the same event under three implementations, and the
# subtest description moves to a different side of the status word in each.
#
# The subtest form is why the summary must be read at all. With
# `unittest.TestCase.subTest`, the failure is reported ONLY under its own
# status word while the PARENT's verbose line still reads PASSED: the counter
# that would flip the parent to failed is incremented by the `subtests`
# FIXTURE alone (_pytest/subtests.py), never by
# _pytest/unittest.py::addSubTest. Reading verbose lines alone therefore scores
# a solution that failed every subtest of a graded test as PASSED -- a false
# ACCEPT, which no pass-rate metric can surface.
_STATUS_WORDS = {
    "PASSED": TestStatus.PASSED,
    "XPASS": TestStatus.PASSED,
    "XPASSED": TestStatus.PASSED,
    "SUBPASS": TestStatus.PASSED,
    "SUBPASSED": TestStatus.PASSED,
    "FAILED": TestStatus.FAILED,
    "SUBFAIL": TestStatus.FAILED,
    "SUBFAILED": TestStatus.FAILED,
    "SKIPPED": TestStatus.SKIPPED,
    "XFAIL": TestStatus.SKIPPED,
    "ERROR": TestStatus.ERROR,
}

# SUBSKIPPED and SUBXFAIL are absent on purpose, and completing the map BREAKS
# grading: SKIPPED outranks PASSED in _SEVERITY below, so folding a skipped
# subtest onto its parent turns a passing graded test into SKIPPED, which the
# scorer counts as not passing. Only the pass and fail directions belong here.
#
# Both spellings of each subtest word are needed: the standalone
# pytest-subtests plugin emits SUBFAIL/SUBPASS, pytest 9's builtin emits
# SUBFAILED/SUBPASSED. This scaffold pins no pytest version -- the task's own
# repo installs it -- so the parser cannot target one implementation.

# Longest first, so SUBFAILED is not read as SUBFAIL with trailing junk.
_STATUS_BY_LEN = sorted(_STATUS_WORDS, key=len, reverse=True)

# A node id is `<path>.<ext>::<rest>`, and <rest> can hold almost anything: a
# parametrize group carries arbitrary repr text, so it may contain spaces
# (`test_p[a b]`), a ` - ` (`test_p[a - b]`), nested brackets
# (`test_p[bracket[inner]]`) or brackets that do not balance at all --
# `test_seq[error-75-\x1b]9;4;2;75\x1b\\]` is a real id from pytest's own
# suite. Any pattern that tries to DESCRIBE that content gets it wrong in one
# of two directions: stop at the first `]` and the id truncates, run greedy and
# it swallows the failure message behind it.
#
# So the id is SCANNED rather than matched: it ends at the first whitespace
# that is not inside a bracket, which is the same rule pytest uses to print it.
# The id must survive whole or it can never string-equal its config.json entry
# (rule 4 above), and the grader counts a name it cannot find as not passing.
# An earlier version anchored the pattern on `tests/`, so a repo-rooted
# `nacl/tests/test_x.py::test_y` matched from the middle and the whole task
# scored 0/N while the log reported it passing.
_NODE_ID_HEAD = re.compile(r"[^\s]*\.\w+::")


def _node_id_at(text: str) -> "str | None":
    # Requiring a leading `<path>.<ext>::` is what stops an ordinary log line
    # (`ERROR twisted: lost host::9092 retrying`) from minting a test that
    # never existed.
    if _NODE_ID_HEAD.match(text) is None:
        return None
    depth = 0
    for index, char in enumerate(text):
        if char == "[":
            depth += 1
        elif char == "]":
            # Clamped, never negative: an unbalanced `]` inside an id is
            # content, not the end of a group.
            depth = max(0, depth - 1)
        elif depth == 0 and char.isspace():
            return text[:index] or None
    return text or None


# One bracketed group. The same shape covers all four things pytest writes
# beside a status word: a subtest description, an xdist gateway id, a progress
# percentage and a duration. Round brackets as well as square -- the
# description is whatever _sub_test_description() built, so it is `[msg]` for
# subTest("msg"), `(i=1)` for subTest(i=1), `[msg] (i=1)` for both, and
# `(<subtest>)` for a bare subTest(). subTest(i=1) is the common idiom, and
# matching only `[...]` misses it.
#
# The content is NOT described by a character class, for the same reason the
# node id is scanned rather than matched: the group holds arbitrary text. pytest
# builds it as `f"[{msg}]"` plus `", ".join(f"{k}={saferepr(v)}")`
# (_pytest/subtests.py::_sub_test_description), so `subTest(v=[1, 2])`,
# `subTest(v=(1, 2))` and a msg containing `)` all put a closing delimiter
# INSIDE the group. A class that stops at the first `]` or `)` reads none of
# those lines -- and an unread subtest failure line leaves the parent reading
# PASSED, which is the false ACCEPT this parser exists to close.
#
# So groups are SKIPPED, not matched: _scan_gap walks whitespace, [...] / (...)
# groups and hostile residue in a single linear pass, with no length limit and
# no limit on the group count. An earlier version expressed the same idea as a
# lazy regex bounded to 3 groups of 200 chars; the bounds were load-bearing
# against catastrophic backtracking ('(?:\s*_DESC)*' explores every partition
# of a bracket run -- 20.7s on 'FAILED ' + '[a] ' x 1000), but a line past
# either bound was silently dropped, which is the same false accept this
# parser exists to close. Every character below advances the cursor, so the
# hostile line costs one pass (~ms) with nothing to exceed.
def _skip_group(text: str, pos: int) -> int:
    # Consume one [...] or (...) group, ending at the first closing delimiter
    # of either kind: the description is arbitrary text, so an opener need not
    # balance ('[a[b]' is one description whose msg held '['). Same end rule
    # the old pattern used; the residue scan below covers the tail when the
    # msg held a closer ('[a]b]'). Unterminated: consume to end of line, and
    # the status/node check that follows fails the line.
    end = len(text)
    pos += 1
    while pos < end:
        if text[pos] in "])":
            return pos + 1
        pos += 1
    return end


def _match_status_at(text: str, pos: int) -> "tuple[str, int] | None":
    # A status word starting exactly at pos, longest vocabulary word first.
    # The trailing boundary stops 'XFAILED' or 'SUBFAILEDX' prose from
    # matching; the leading boundary holds by construction (the gap scanner
    # only ever stops at whitespace, a group end, or line start).
    for word in _STATUS_BY_LEN:
        end = pos + len(word)
        if text.startswith(word, pos) and (
            end >= len(text) or not (text[end].isalnum() or text[end] == "_")
        ):
            return word, end
    return None


def _scan_gap(text: str, pos: int) -> int:
    # Advance over everything pytest may print between the anchors: whitespace,
    # bracket groups (unbounded) and hostile residue.
    #
    # Residue is a tail the strict group scan leaves behind: '[a]b]' is ONE
    # description whose msg held ']', so the opener half is consumed as a group
    # and 'b]' is left over. A run only counts as residue when it carries a
    # closing delimiter AND is neither a node id nor a status word where it
    # stands -- those guards keep real anchors intact ('test_p[a - b]' is never
    # swallowed, 'FAILED]' is never skipped past). A run without any closer is
    # prose, and the scan stops, exactly as the old pattern did when no group
    # shape fit.
    #
    # One deliberate asymmetry with the old backtracker: a group never spans
    # node-shaped text, even when doing so would complete a match (the old
    # engine could swallow '<node>' into a description on contrived lines like
    # '[ ] <node> STATUS <node>'). Swallowing an id breaks the rule the node
    # scan exists for -- it must survive whole to string-equal its config.json
    # entry -- so the node guard wins and the line is dropped instead.
    end = len(text)
    while pos < end:
        char = text[pos]
        if char.isspace():
            pos += 1
        elif char in "[(":
            pos = _skip_group(text, pos)
        else:
            token_end = pos
            while token_end < end and not text[token_end].isspace():
                token_end += 1
            token = text[pos:token_end]
            # The '::' pre-check keeps the node guard O(1) for ordinary
            # residue: a node id always carries '::' (_NODE_ID_HEAD), so only
            # a token that even could be one pays for the real scan.
            if (
                ("]" in token or ")" in token)
                and ("::" not in token or _node_id_at(text[pos:]) is None)
                and _match_status_at(text, pos) is None
            ):
                pos = token_end
            else:
                break
    return pos

# 'STATUS <node id>' and '<node id> STATUS', with descriptions allowed on
# EITHER side of the status word, because which side they land on is not
# stable across implementations:
#
#   FAILED <node> - AssertionError                pytest, plain
#   SUBFAILED(i=3) <node> - AssertionError        pytest 9 builtin subtests
#   (i=3) SUBFAIL <node>                          pytest-subtests 0.15
#   [label] (i=1) SUBFAIL <node>                  ditto, two groups
#   [gw0] [ 50%] FAILED <node>                    xdist
#   FAILED [1.1667s] <node>                       xdist, duration
#
# Accepting only one side is a false ACCEPT rather than a parse error: the
# subtest's failure line goes unread while the parent's own line still says
# PASSED, so a solution that failed every subtest of a graded test is paid in
# full. All three subtest spellings above were measured on real logs.
#
# The summary form is tried FIRST: a summary message can itself contain a
# status word ("... - ValueError: ERROR in config"), which the verbose scan
# below would otherwise read as this line's status.
def _parse_line(line: str) -> "TestResult | None":
    pos = _scan_gap(line, 0)
    summary = _match_status_at(line, pos)
    if summary is not None:
        word, end = summary
        node_pos = _scan_gap(line, end)
        # Whitespace separates the status word from its node id: without it
        # 'SUBFAILED(i=3)node' would glue a description to its node id.
        if node_pos > end and line[node_pos - 1].isspace():
            name = _node_id_at(line[node_pos:])
            if name is not None:
                return TestResult(name=name, status=_STATUS_WORDS[word])

    name = _node_id_at(line)
    if name is None:
        return None
    pos = len(name)
    # '<node id> STATUS', pytest's verbose line when not running under xdist.
    # The description sits BETWEEN the two under pytest-subtests 0.15
    # ('<node> (i=1) SUBFAIL   [ 75%]'). Whitespace separates the node id from
    # whatever follows it.
    if pos >= len(line) or not line[pos].isspace():
        return None
    verbose = _match_status_at(line, _scan_gap(line, pos))
    if verbose is None:
        return None
    return TestResult(name=name, status=_STATUS_WORDS[verbose[0]])

# A repo carrying `--color=yes` in its addopts wraps every status word in
# escape codes; without stripping them the parse comes back entirely empty.
_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]")


def parse_test_output(stdout_content: str, stderr_content: str) -> List[TestResult]:
    results = []

    # Line by line, never over the joined text: `\s+` matches a newline, so a
    # whole-blob scan pairs a node id at the end of one line with the NEXT
    # line's status word. Duplicate node ids are expected here (a test appears
    # in both the verbose line and the summary) -- export_to_json resolves them
    # worst-status-wins.
    for line in (stdout_content + "\n" + stderr_content).splitlines():
        parsed = _parse_line(_ANSI_RE.sub("", line).rstrip())
        if parsed is not None:
            results.append(parsed)

    return results


### Implement the parsing logic above ###
### DO NOT MODIFY THE CODE BELOW ###


_VALID_STATUSES = {"PASSED", "FAILED", "SKIPPED", "ERROR"}


def _fail_contract(message: str) -> None:
    banner = "!" * 72
    print(banner, file=sys.stderr)
    print("PARSER CONTRACT VIOLATION", file=sys.stderr)
    print(message, file=sys.stderr)
    print("See docs/test-output-contract.md for the required output shape.", file=sys.stderr)
    print(banner, file=sys.stderr)
    sys.exit(1)


def validate_contract(output_path: Path) -> None:
    try:
        payload = json.loads(output_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        _fail_contract(f"Could not read valid JSON from {output_path}: {e}")

    if not isinstance(payload, dict) or "tests" not in payload:
        _fail_contract(f"Output must be an object with a top-level 'tests' key, got: {type(payload).__name__}")

    tests = payload["tests"]
    if not isinstance(tests, list):
        _fail_contract(f"'tests' must be a list, got: {type(tests).__name__}")

    for i, entry in enumerate(tests):
        if not isinstance(entry, dict):
            _fail_contract(f"tests[{i}] must be a dict, got: {type(entry).__name__}")
        if "name" not in entry or "status" not in entry:
            _fail_contract(f"tests[{i}] missing required keys (name, status): {entry!r}")
        if not isinstance(entry["name"], str) or not isinstance(entry["status"], str):
            _fail_contract(f"tests[{i}] name/status must be strings: {entry!r}")
        if entry["status"] not in _VALID_STATUSES:
            _fail_contract(
                f"tests[{i}] has invalid status {entry['status']!r}; "
                f"must be one of {sorted(_VALID_STATUSES)}"
            )

    if not tests:
        print(
            "WARNING: parser produced an empty tests list. "
            "This is almost certainly a parser bug (regex mismatch or empty logs).",
            file=sys.stderr,
        )


# pytest's own footer, an independent statement of the same run:
#   ===== 9 failed, 7 passed, 1 skipped in 0.02s =====
# Only `failed` is counted. A collection error reports `error` and aborts the
# session before any test runs, which leaves the parse legitimately empty.
_FOOTER_FAILED_RE = re.compile(r"^=+ .*?\b(\d+) failed\b.*=+$", re.M)


def validate_against_pytest_summary(
    stdout_content: str, stderr_content: str, results: List[TestResult]
) -> None:
    # parse_test_output can only recognise status words it already knows, and
    # the set is not stable: the standalone pytest-subtests plugin, pytest 9's
    # builtin and pytest 7 all spell them differently. The dangerous failure is
    # narrow -- a failure reported under an UNKNOWN word while the parent's own
    # line still reads PASSED -- and it pays a full reward for a solution that
    # failed, which no pass-rate or rejection-rate metric can surface.
    #
    # pytest counting failures while the parse holds none is a contradiction no
    # future format change can make true, so it is checked here rather than
    # left to whatever parsing logic an author writes above.
    if not results:
        return

    # ANSI is stripped first, exactly as parse_test_output does. Under
    # `--color=yes` pytest writes the footer as
    # `\x1b[31m===== 1 failed in 0.02s =====\x1b[0m`, so the line begins with an
    # escape rather than `=` and _FOOTER_FAILED_RE's `^=+` never matches. That
    # failure is silent and points the wrong way: `reported` comes back 0, the
    # cross-check below cannot fire, and the run is graded on a parse that may
    # hold no failure at all -- the false ACCEPT this function exists to stop.
    reported = sum(
        int(count)
        for count in _FOOTER_FAILED_RE.findall(
            _ANSI_RE.sub("", stdout_content + "\n" + stderr_content)
        )
    )
    if reported and not any(
        result.status in (TestStatus.FAILED, TestStatus.ERROR) for result in results
    ):
        _fail_contract(
            f"pytest reported {reported} failed test(s) but the parse contains no "
            "FAILED or ERROR entry. A failure is being reported under a status "
            "word parse_test_output does not recognise; grading this run would "
            "reward a solution that failed."
        )


_SEVERITY = {
    TestStatus.PASSED: 0,
    TestStatus.SKIPPED: 1,
    TestStatus.FAILED: 2,
    TestStatus.ERROR: 3,
}


def export_to_json(results: List[TestResult], output_path: Path) -> None:
    # Worst status wins when a node id appears more than once. A test that
    # failed ANY subtest failed, whatever its parent's verbose line said, and
    # the grader counts only PASSED -- so a later pass must never overwrite an
    # earlier non-pass. This replaced a last-wins dict comprehension, under
    # which the verdict depended on line ORDER in the log.
    #
    # Deliberately here rather than in parse_test_output: this half of the
    # contract has to hold whatever parsing logic an author writes above.
    worst = {}
    for result in results:
        current = worst.get(result.name)
        if current is None or _SEVERITY[result.status] > _SEVERITY[current.status]:
            worst[result.name] = result

    json_results = {
        "tests": [
            {"name": result.name, "status": result.status.name} for result in worst.values()
        ]
    }

    with open(output_path, "w") as f:
        json.dump(json_results, f, indent=2)


def main(stdout_path: Path, stderr_path: Path, output_path: Path) -> None:
    with open(stdout_path) as f:
        stdout_content = f.read()
    with open(stderr_path) as f:
        stderr_content = f.read()

    results = parse_test_output(stdout_content, stderr_content)
    export_to_json(results, output_path)
    validate_contract(output_path)
    validate_against_pytest_summary(stdout_content, stderr_content, results)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python parser.py <stdout_file> <stderr_file> <output_json>")
        sys.exit(1)

    main(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
