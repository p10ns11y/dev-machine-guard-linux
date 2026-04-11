#!/bin/bash
# =============================================================================
# Unit Tests for DevGuard - Package Scanning
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_SCRIPT="$PROJECT_DIR/security-dev-machine-guard.sh"

# Resolve to absolute path
MAIN_SCRIPT="$(cd "$(dirname "$MAIN_SCRIPT")" && pwd)/$(basename "$MAIN_SCRIPT")"
FIXTURES="$SCRIPT_DIR/fixtures"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

passed=0
failed=0

log_pass() { printf "${GREEN}PASS${RESET}: %s\n" "$1"; ((passed++)) || true; }
log_fail() { printf "${RED}FAIL${RESET}: %s\n" "$1"; ((failed++)) || true; }

echo "=== DevGuard Package Scan Tests ==="
echo

# Test 1: Find package in mock project
echo "Test 1: Find package in mock project"
output=$(timeout 10 bash "$MAIN_SCRIPT" --package axios --search-path "$FIXTURES/project1" --no-ide --no-ai 2>&1) || true
if echo "$output" | grep -qi "axios"; then
    log_pass "Package found in fixture"
else
    log_fail "Package not found: $output"
fi

# Test 2: Version regex matching
echo "Test 2: Version regex matching"
output=$(timeout 10 bash "$MAIN_SCRIPT" --package axios --version "1\.14" --search-path "$FIXTURES/project1" --no-ide --no-ai 2>&1) || true
if echo "$output" | grep -qi "MATCH"; then
    log_pass "Version regex works"
else
    log_fail "Version regex failed: $output"
fi

# Test 3: Exclude dir works
echo "Test 3: Exclude directory"
(
    cd "$FIXTURES"
    mkdir -p project1/node_modules/axios
    if timeout 10 bash "$MAIN_SCRIPT" --package axios --no-ide --no-ai --exclude-dir node_modules 2>&1 | grep -q "node_modules"; then
        log_fail "Excluded dir still found"
    else
        log_pass "Exclude directory works"
    fi
    rmdir project1/node_modules/axios 2>/dev/null || true
    rmdir project1/node_modules 2>/dev/null || true
)

# Summary
echo
echo "=== Summary ==="
printf "Passed: %d\n" "$passed"
printf "Failed: %d\n" "$failed"

if [ "$failed" -gt 0 ]; then
    exit 1
fi