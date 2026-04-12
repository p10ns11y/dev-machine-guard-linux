#!/usr/bin/env bash
# =============================================================================
# Extra Detector: Git History Search for DevGuard
# Load with: ./devguard.sh --package axios --add-detector ./git-history-search.sh
# =============================================================================

scan_git_history() {
    [[ -z "$PACKAGE_NAME" ]] && return 0
    
    emit "${D}→ Checking git history of lockfiles for $PACKAGE_NAME...${X}"
    
    [[ -f /tmp/devguard_interrupted ]] && return $EXIT_INTERRUPTED
    
    local search_root
    search_root=$(get_search_root)
    
    local excl
    excl=$(build_exclude_args)
    
    local lockfile_pattern="-type f \( -name package-lock.json -o -name pnpm-lock.yaml -o -name bun.lockb -o -name yarn.lock \)"
    
    for search_path in $search_root; do
        while IFS= read -r lockfile; do
            check_interrupt
            [[ -f /tmp/devguard_interrupted ]] && return $EXIT_INTERRUPTED
            
            local dir
            dir=$(dirname "$lockfile")
            [[ ! -d "$dir/.git" ]] && continue
            
            local commits
            commits=$(timeout "${TIMEOUT_SECS:-30}" git -C "$dir" log --oneline -S "$PACKAGE_NAME" -- "$lockfile" 2>/dev/null | head -8) || true
            
            while IFS= read -r commit_line; do
                check_interrupt
                [[ -f /tmp/devguard_interrupted ]] && return $EXIT_INTERRUPTED
                
                local commit message date old_version
                commit=$(echo "$commit_line" | awk '{print $1}')
                message=$(echo "$commit_line" | cut -d' ' -f2-)
                date=$(timeout "${TIMEOUT_SECS:-30}" git -C "$dir" show -s --format=%cd --date=short "$commit" 2>/dev/null) || true
                old_version=$(timeout "${TIMEOUT_SECS:-30}" git -C "$dir" show "$commit" -- "$lockfile" 2>/dev/null | \
                    grep -oE "${PACKAGE_NAME}[^\"']*[\"']?\s*:\s*[\"']?[^\"',}]+" | head -1) || true
                
                if [[ -n "$old_version" ]]; then
                    emit "${R}⚠ FOUND IN GIT HISTORY${X} → $lockfile"
                    emit "   ${D}Commit:${X} $commit | ${D}Date:${X} $date"
                    emit "   ${D}Message:${X} $message"
                    emit "   ${D}Version at that time:${X} $old_version"
                    echo
                fi
            done <<< "$commits"
        done < <(find "$search_path" $lockfile_pattern $excl 2>/dev/null)
    done
}

run_extra_detectors() {
    scan_git_history
}

EXTRA_DETECTOR_FUNCTIONS+=("scan_git_history")