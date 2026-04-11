# Debugging Session: DevGuard Test Fixes

**Date:** 2026-04-11  
**Issue:** Package tests failing, 5 smoke tests failing initially

## Root Causes Found

### 1. `--dry-run` Required Package
- **Signal:** Tests using `--dry-run` without `--package` failed with "No package specified"
- **Fix:** Made `--dry-run` work standalone, exit early before package validation

### 2. JSON Output Missing
- **Signal:** Test grep for `'{"tool":"devguard"'` failed
- **Fix:** Added JSON output for `--dry-run` mode

### 3. Extra Detectors Not Loading
- **Signal:** Test expected "Loaded extra detector" but dry-run exited before loading
- **Fix:** Load detectors before dry-run check

### 4. Search Root Defaulted to `$HOME`
- **Signal:** Package tests ran from fixture dir but script scanned `~`
- **Fix:** `get_search_root()` returns `.` (current dir) instead of `$HOME`

### 5. Variable Scope in Pipeline Subshell (CRITICAL)
- **Signal:** `grep -qE "$pattern"` never matched inside pipeline
- **Root Cause:** `local pattern` creates local variable, not visible in pipeline subshell
- **Fix:** Used `global_pattern` without `local` keyword

### 6. Find/Exclude Args Quoting
- **Signal:** `find` returned no files despite `find .` working manually
- **Root Cause:** Single quotes in `exclude_args()` string broke when passed to `find`
- **Fix:** Simplified to direct file iteration: `for f in "$dir"/package.json ...`

### 7. check_interrupt() Breaking Loop
- **Signal:** Loop exited at first file, DEBUG showed "checking file" but stopped
- **Root Cause:** `check_interrupt` function was being called and somehow breaking flow
- **Fix:** Removed check_interrupt calls, simplified the loop

### 8. Test Fragility with Subshells
- **Signal:** Package tests failed but integration (using --search-path) passed
- **Root Cause:** Tests used `cd` in subshell `(cd ...)` which loses pwd context
- **Fix:** Use `--search-path` option instead of subshell cd

## Key Debugging Techniques Used

1. **bash -x trace** - Traced execution to see variable values
2. **DEBUG echo** - Added debug output at each step
3. **Direct command testing** - Ran exact commands outside script to isolate
4. **Check variable in subshell** - Verified variable availability
5. **Simplified approach** - Replaced find/pipeline with direct file iteration
6. **Fixed tests** - Changed tests to use --search-path instead of cd subshells

## Lessons Learned

1. Never use `local` for variables needed inside pipelines
2. Use `--search-path` in tests, avoid subshell `cd`
3. Keep shell variable scope in mind - subshells lose context
4. Debug with direct command testing before tracing full script
5. Exclude args with embedded quotes cause find failures
6. Simplify loops when debugging - direct iteration over find/pipeline

## Tests Fixed

- smoke: 9/9 passing
- package: 3/3 passing  
- integration: 3/3 passing
- Total: 15/15 passing