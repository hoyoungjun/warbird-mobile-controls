#!/bin/bash
set -e

# -rap prints the short test summary for every outcome. parser.py needs it
# because under pytest-xdist the per-test line is written as
# `[gw0] [ 50%] STATUS <node id>`, and a PASSING test is recoverable from
# nowhere else. `p` and not `P`: `P` additionally dumps every passing test's
# captured stdout into the log, and SWE-bench includes repos whose own output
# is full of node ids and status words for these patterns to misread.
#
# A subtest failure reaches the summary with or without this flag -- pytest's
# default is `-r fE` and SUBFAILED is categorised failed -- but the summary is
# the ONLY place it appears when the test uses `unittest.TestCase.subTest`:
# there is no verbose line for the subtest itself, and the parent's reads
# PASSED. (The `subtests` fixture does emit one, and flips its parent.) See
# the parser's summary scan in _parse_line.

run_all_tests() {
  echo "Running all tests..."
  cd /app
  python3 -m pytest -v -rap --tb=short || true
}

run_selected_tests() {
  local test_files=("$@")
  echo "Running selected tests: ${test_files[@]}"
  cd /app

  for test_file in "${test_files[@]}"; do
    echo "Running test: $test_file"
    test_path=$(echo "$test_file" | sed 's/::.*//')
    python3 -m pytest "$test_path" -v -rap --tb=short || true
  done
}

if [ $# -eq 0 ]; then
  run_all_tests
  exit $?
fi

if [[ "$1" == *","* ]]; then
  IFS=',' read -r -a TEST_FILES <<< "$1"
else
  TEST_FILES=("$@")
fi

run_selected_tests "${TEST_FILES[@]}"
