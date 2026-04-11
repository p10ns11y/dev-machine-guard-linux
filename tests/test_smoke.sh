#!/bin/bash
# =============================================================================
# Smoke Tests for DevGuard
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_SCRIPT="$PROJECT_DIR/security-dev-machine-guard.sh"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

passed=0
failed=0

log_pass() { printf "${GREEN}PASS${RESET}: %s\n" "$1"; ((passed++)) || true; }
log_fail() { printf "${RED}FAIL${RESET}: %s\n" "$1"; ((failed++)) || true; }
log_skip() { printf "${YELLOW}SKIP${RESET}: %s\n" "$1"; }

run_quiet_long() {
    timeout 60 "$MAIN_SCRIPT" "$@" 2>&1 || true
}

echo "=== DevGuard Smoke Tests ==="
echo

# Test 1: Script exists
echo "Test 1: Script exists"
if [ -f "$MAIN_SCRIPT" ]; then
    log_pass "Script exists"
else
    log_fail "Script missing"
fi

# Test 2: Help works
echo "Test 2: Help output"
output=$("$MAIN_SCRIPT" --help 2>&1) || true
if echo "$output" | grep -q "DevGuard Scanner"; then
    log_pass "Help displays correctly"
else
    log_fail "Help output missing"
fi

# Test 3: Dry run works
echo "Test 3: Dry run mode"
output=$(run_quiet_long --dry-run 2>&1) || true
if echo "$output" | grep -q "Dry run complete"; then
    log_pass "Dry run works"
else
    log_fail "Dry run failed: $output"
fi

# Test 4: JSON output
echo "Test 4: JSON output format"
output=$(run_quiet_long --json --dry-run 2>&1) || true
if echo "$output" | grep -q '{"tool":"devguard"'; then
    log_pass "JSON output valid"
else
    log_fail "JSON output invalid"
fi

# Test 5: Color mode never
echo "Test 5: Color mode never"
output=$(run_quiet_long --color never --dry-run 2>&1) || true
if ! echo "$output" | grep -qE '\\033'; then
    log_pass "Color disabled"
else
    log_fail "Color still present"
fi

# Test 6: Package validation rejects invalid
echo "Test 6: Invalid package name rejected"
if (bash "$MAIN_SCRIPT" --package '=' 2>&1 || true) | grep -qi "invalid"; then
    log_pass "Input validation works"
else
    log_fail "Input validation failed"
fi

# Test 7: Exclude dir option
echo "Test 7: Exclude directory option"
output=$(run_quiet_long --exclude-dir foo --dry-run 2>&1) || true
if echo "$output" | grep -q "Excluding: foo"; then
    log_pass "Exclude directory accepted"
else
    log_fail "Exclude directory failed: $output"
fi

# Test 8: Search path option
echo "Test 8: Search path option"
output=$(run_quiet_long --search-path /tmp --dry-run 2>&1) || true
if echo "$output" | grep -q "Search paths: /tmp"; then
    log_pass "Search path accepted"
else
    log_fail "Search path failed: $output"
fi

# Test 9: Extra detector loading
echo "Test 9: Extra detector loading"
detector="$PROJECT_DIR/git-history-search.sh"
if [ -f "$detector" ]; then
    output=$(run_quiet_long --add-detector "$detector" --dry-run 2>&1) || true
    if echo "$output" | grep -q "Loaded extra detector"; then
        log_pass "Extra detector loads"
    else
        log_fail "Extra detector not loaded: $output"
    fi
else
    log_skip "Extra detector file missing"
fi

# Summary
echo
echo "=== Summary ==="
printf "Passed: %d\n" "$passed"
printf "Failed: %d\n" "$failed"
echo

if [ "$failed" -gt 0 ]; then
    echo "Some tests failed!"
    exit 1
else
    echo "All smoke tests passed!"
    exit 0
fi