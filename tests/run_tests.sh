#!/usr/bin/env bash
# Run all tests and report overall pass/fail
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_SUITES=()

run_suite() {
    local script="$1"
    local name
    name="$(basename "$script")"

    output=$(bash "$script" 2>&1) || true
    local exit_code=$?
    # re-check: count failures from output since set -e in subshell may exit early
    exit_code=$(echo "$output" | grep -c "^  FAIL" || true)

    echo "$output"
    echo ""

    local pass fail
    pass=$(echo "$output" | grep -c "^  PASS" || true)
    fail=$(echo "$output" | grep -c "^  FAIL" || true)
    TOTAL_PASS=$((TOTAL_PASS + pass))
    TOTAL_FAIL=$((TOTAL_FAIL + fail))

    if [[ $fail -gt 0 ]] || [[ $exit_code -ne 0 ]]; then
        FAILED_SUITES+=("$name")
    fi
}

for test_script in "$TESTS_DIR"/test_*.sh; do
    run_suite "$test_script"
done

echo "========================================"
echo "Total: $TOTAL_PASS passed, $TOTAL_FAIL failed"

if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
    echo "Failed suites: ${FAILED_SUITES[*]}"
    exit 1
fi

echo "All tests passed."
