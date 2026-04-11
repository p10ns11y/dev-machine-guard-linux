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

# Test 4: Multi-project scan finds packages in both projects
echo "Test 4: Multi-project scan"
output=$(timeout 30 bash "$MAIN_SCRIPT" --package axios --search-path "$FIXTURES" --no-ide --no-ai 2>&1) || true
if echo "$output" | grep -qi "project1" && echo "$output" | grep -qi "project2"; then
    log_pass "Multi-project scan works"
else
    log_fail "Multi-project scan failed"
fi

# Test 5: Version comparison across projects
echo "Test 5: Version comparison"
output=$(timeout 30 bash "$MAIN_SCRIPT" --package axios --search-path "$FIXTURES" --no-ide --no-ai 2>&1) || true
if echo "$output" | grep -qi "1.14" && echo "$output" | grep -qi "0.21"; then
    log_pass "Version comparison works"
else
    log_fail "Version comparison failed"
fi

# Test 6: Different packages in project2 only
echo "Test 6: Project2 unique package"
output=$(timeout 30 bash "$MAIN_SCRIPT" --package react --search-path "$FIXTURES/project2" --no-ide --no-ai 2>&1) || true
if echo "$output" | grep -qi "react"; then
    log_pass "Project2 unique package found"
else
    log_fail "Project2 unique package not found"
fi

# Test 7: Project1 unique package (lodash not in project2)
echo "Test 7: Project1 unique package"
output=$(timeout 30 bash "$MAIN_SCRIPT" --package lodash --search-path "$FIXTURES/project1" --no-ide --no-ai 2>&1) || true
if echo "$output" | grep -qi "lodash"; then
    log_pass "Project1 unique package found"
else
    log_fail "Project1 unique package not found"
fi

# Test 8: Non-existent package returns no matches
echo "Test 8: Non-existent package"
output=$(timeout 30 bash "$MAIN_SCRIPT" --package nonexistentpkg --search-path "$FIXTURES" --no-ide --no-ai 2>&1) || true
if ! echo "$output" | grep -qi "MATCH"; then
    log_pass "Non-existent package handled"
else
    log_fail "Non-existent package false positive"
fi

# Summary
echo
echo "=== Summary ==="
printf "Passed: %d\n" "$passed"
printf "Failed: %d\n" "$failed"
[ "$failed" -eq 0 ] && echo "All tests passed!"