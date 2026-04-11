#!/bin/bash
# =============================================================================
# Integration Tests for DevGuard - Package Scanning
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_SCRIPT="$PROJECT_DIR/security-dev-machine-guard.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

RED='\033[31m'
GREEN='\033[32m'
RESET='\033[0m'

passed=0
failed=0

log_pass() { printf "${GREEN}PASS${RESET}: %s\n" "$1"; ((passed++)) || true; }
log_fail() { printf "${RED}FAIL${RESET}: %s\n" "$1"; ((failed++)) || true; }

echo "=== DevGuard Integration Tests ==="
echo

# Test 1: Search-path finds package
echo "Test 1: Search-path finds package"
output=$(timeout 30 bash "$MAIN_SCRIPT" --package axios --search-path "$FIXTURES/project1" --no-ide --no-ai 2>&1) || true
if echo "$output" | grep -qi "axios"; then
    log_pass "Search-path finds package"
else
    log_fail "Search-path failed: $output"
fi

# Test 2: Version regex matching
echo "Test 2: Version regex"
output=$(timeout 30 bash "$MAIN_SCRIPT" --package axios --version "1\.14" --search-path "$FIXTURES/project1" --no-ide --no-ai 2>&1) || true
if echo "$output" | grep -qi "MATCH"; then
    log_pass "Version regex works"
else
    log_fail "Version regex failed"
fi

# Test 3: Exclude-dir works
echo "Test 3: Exclude-dir works"
mkdir -p "$FIXTURES/project1/node_modules"
output=$(timeout 30 bash "$MAIN_SCRIPT" --package axios --search-path "$FIXTURES" --exclude-dir node_modules --no-ide --no-ai 2>&1) || true
rm -rf "$FIXTURES/project1/node_modules"
if ! echo "$output" | grep -q "node_modules"; then
    log_pass "Exclude-dir works"
else
    log_fail "Exclude-dir failed"
fi

# Summary
echo
echo "=== Summary ==="
printf "Passed: %d\n" "$passed"
printf "Failed: %d\n" "$failed"
[ "$failed" -eq 0 ] && echo "All tests passed!"