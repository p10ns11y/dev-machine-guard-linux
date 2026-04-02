#!/bin/bash
# =============================================================================
# Extra Detector: Git History Search
# Load with: ./devguard.sh --package axios --add-detector ./git-history-search.sh
# =============================================================================

scan_git_history() {
    [ -z "$PACKAGE_NAME" ] && return

    print "${DIM}→ Checking git history of lockfiles for ${PACKAGE_NAME}...${RESET}"

    find ~ -type f \( -name package-lock.json -o -name pnpm-lock.yaml -o -name bun.lockb -o -name yarn.lock \) \
        -not -path "*/Trash/*" -not -path "*/node_modules/*" 2>/dev/null | while read -r lockfile; do

        dir=$(dirname "$lockfile")
        [ -d "$dir/.git" ] || continue

        git -C "$dir" log --oneline -S "$PACKAGE_NAME" -- "$lockfile" | head -8 | while read -r commit_line; do
            commit=$(echo "$commit_line" | awk '{print $1}')
            message=$(echo "$commit_line" | cut -d' ' -f2-)
            date=$(git -C "$dir" show -s --format=%cd --date=short "$commit" 2>/dev/null)
            old_line=$(git -C "$dir" show "$commit" -- "$lockfile" 2>/dev/null | grep -oE "${PACKAGE_NAME}[^\"']*[\"']?\s*:\s*[\"']?[^\"',}]+" | head -1 || echo "")

            if [ -n "$old_line" ]; then
                print "${RED}⚠️  FOUND IN GIT HISTORY${RESET} → $lockfile"
                print "   ${DIM}Commit:${RESET} $commit | ${DIM}Date:${RESET} $date"
                print "   ${DIM}Message:${RESET} $message"
                print "   ${DIM}Version at that time:${RESET} ${old_line}"
                echo
            fi
        done
    done
}

# Register this detector so the main script can call it
run_extra_detectors() {
    scan_git_history
}

# Register this detector (this is the clean way to support multiple detectors)
EXTRA_DETECTOR_FUNCTIONS+=("scan_git_history")