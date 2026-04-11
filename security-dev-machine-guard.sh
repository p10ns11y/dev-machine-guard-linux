#!/bin/bash
# =============================================================================
# DevGuard Scanner - Core (lean & classy)
# Modular design: extra detectors can be loaded with --add-detector
# =============================================================================

set -euo pipefail
shopt -s inherit_ubsan 2>/dev/null || true

INTERRUPTED=false
interrupt_handler() {
    INTERRUPTED=true
    touch /tmp/devguard_interrupted
    echo -e "${YELLOW}⚠️  Scan interrupted by user. Cleaning up...${RESET}" >&2
    exit 130
}
trap 'interrupt_handler' INT TERM

check_interrupt() {
    if [ -f /tmp/devguard_interrupted ]; then
        echo -e "${YELLOW}⚠️  Scan interrupted by user.${RESET}" >&2
        exit 130
    fi
}

CONFIG_FILE="${HOME}/.devguardrc"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# ----------------------------- CLI PARSING -----------------------------------
PACKAGE_NAME="${PACKAGE_NAME:-}"
PACKAGE_VERSION="${PACKAGE_VERSION:-}"
ENABLE_NODE="${ENABLE_NODE:-true}"
ENABLE_IDE="${ENABLE_IDE:-true}"
ENABLE_AI="${ENABLE_AI:-true}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-pretty}"
QUIET="${QUIET:-false}"
COLOR_MODE="${COLOR_MODE:-auto}"
TIMEOUT="${TIMEOUT:-30}"
DRY_RUN="${DRY_RUN:-false}"
SCAN_ALL_MODE="${SCAN_ALL_MODE:-false}"
EXCLUDE_DIRS=()
SEARCH_PATHS=()
EXTRA_DETECTORS=()
EXTRA_DETECTOR_FUNCTIONS=()

command_timeout() {
    local secs="${1:-30}"
    if command -v timeout >/dev/null 2>&1; then
        timeout "$secs" "$2" "${@:3}"
    else
        "$2" "${@:3}"
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --package)        PACKAGE_NAME="$2"; shift 2 ;;
        --version)        PACKAGE_VERSION="$2"; shift 2 ;;
        --node)           ENABLE_NODE=true; shift ;;
        --no-node)        ENABLE_NODE=false; shift ;;
        --ide)            ENABLE_IDE=true; shift ;;
        --no-ide)         ENABLE_IDE=false; shift ;;
        --ai)             ENABLE_AI=true; shift ;;
        --no-ai)          ENABLE_AI=false; shift ;;
        --add-detector)   EXTRA_DETECTORS+=("$2"); shift 2 ;;
        --quiet)          QUIET=true; shift ;;
        --timeout)        TIMEOUT="$2"; shift 2 ;;
        --color)          COLOR_MODE="$2"; shift 2 ;;
        --json)           OUTPUT_FORMAT="json"; shift ;;
        --exclude-dir)    EXCLUDE_DIRS+=("$2"); shift 2 ;;
        --search-path)    SEARCH_PATHS+=("$2"); shift 2 ;;
        --dry-run)        DRY_RUN=true; shift ;;
        --all)           SCAN_ALL_MODE=true; shift ;;
        -h|--help)
            cat <<EOF
DevGuard Scanner

Usage: $0 [options]

Options:
  --package NAME             Package name to search for
  --version REGEX            Version regex (optional)
  --node / --no-node         Node.js scanning
  --ide / --no-ide           IDE extensions
  --ai / --no-ai             AI tools
  --add-detector FILE        Load extra detector script (can be repeated)
  --quiet                    Suppress messages
  --timeout SECS             Command timeout (default: 30)
  --color (auto|never)       Color output (default: auto, respects NO_COLOR)
  --json                     Output JSON summary
  --exclude-dir DIR          Exclude directory (can be repeated)
  --search-path DIR          Search directory (can be repeated, default: ~)
  --dry-run                  Preview what would be scanned
  --all                     Scan all projects (lists all packages)
  -h, --help                 Show help
EOF
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ----------------------------- COLORS ----------------------------------------
apply_colors() {
    if [[ "$COLOR_MODE" == "never" ]] || [[ -n "${NO_COLOR:-}" ]]; then
        BOLD=''; DIM=''; GREEN=''; RED=''; RESET=''
    else
        BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; RESET='\033[0m'
    fi
}
apply_colors
print() { [ "$QUIET" = true ] && return; echo -e "$*"; }

# ----------------------------- INPUT VALIDATION ------------------------------
if [ "$SCAN_ALL_MODE" = false ] && [ -z "$PACKAGE_NAME" ]; then
    echo "Error: No package specified. Use --package NAME or --all to scan everything."
    echo "       Run with --help for full options."
    exit 1
fi

if [ "$SCAN_ALL_MODE" = true ]; then
    print "${DIM}⚠️  Full scan mode enabled - this may take a while. Press Ctrl+C to cancel.${RESET}"
fi

sanitize_package_name() {
    local pkg="$1"
    if [[ ! "$pkg" =~ ^[a-zA-Z0-9@._/-]+$ ]]; then
        print "${RED}Error: Invalid package name: $pkg${RESET}"
        print "${DIM}Package names may only contain letters, numbers, @, ., _, -, /\n"
        exit 1
    fi
}

if [ -n "$PACKAGE_NAME" ]; then
    sanitize_package_name "$PACKAGE_NAME"
fi

get_search_root() {
    if [ ${#SEARCH_PATHS[@]} -gt 0 ]; then
        printf '%s\n' "${SEARCH_PATHS[@]}"
    else
        echo "$HOME"
    fi
}

exclude_args() {
    local args="-not -path '*/Trash/*' -not -path '*/node_modules/*'"
    for d in "${EXCLUDE_DIRS[@]:-}"; do
        args="$args -not -path '*/$d/*'"
    done
    echo "$args"
}

# ----------------------------- LOAD EXTRA DETECTORS --------------------------
for detector in "${EXTRA_DETECTORS[@]}"; do
    if [ -f "$detector" ]; then
        # shellcheck source=/dev/null
        source "$detector"
        print "${DIM}Loaded extra detector: $detector${RESET}"
    else
        print "${RED}Warning: Detector file not found: $detector${RESET}"
    fi
done

# =============================================================================
# CORE DETECTORS
# =============================================================================
scan_node() {
    print "${BOLD}→ Node.js packages (npm/pnpm/bun/yarn + nvm/mise)${RESET}"

    if [ -n "$PACKAGE_NAME" ]; then
        if [ -n "$PACKAGE_VERSION" ]; then
            pattern="(${PACKAGE_NAME}[\"']?\s*:\s*[\"']?${PACKAGE_VERSION})|(${PACKAGE_NAME}@${PACKAGE_VERSION})|(\"version\"\s*:\s*[\"']?${PACKAGE_VERSION})"
            print "${DIM}Searching for: ${PACKAGE_NAME} version matching ${PACKAGE_VERSION}${RESET}"
        else
            pattern="${PACKAGE_NAME}"
            print "${DIM}Searching for any ${PACKAGE_NAME} (showing actual version)${RESET}"
        fi

        local search_root
        search_root=$(get_search_root)
        local excl
        excl=$(exclude_args)
        # shellcheck disable=SC2086
        find $search_root -type f \(  \
            -name package-lock.json -o \
            -name pnpm-lock.yaml -o \
            -name bun.lockb -o \
            -name yarn.lock -o \
            -name package.json \
        \) $excl 2>/dev/null | while read -r f; do
            check_interrupt

            if grep -qE "$pattern" "$f" 2>/dev/null; then
                if [ -z "$PACKAGE_VERSION" ]; then
                    version=$(grep -oE "${PACKAGE_NAME}[^\"']*[\"']?\s*:\s*[\"']?[^\"',}]+" "$f" 2>/dev/null | head -1 || echo "unknown")
                    print "${RED}⚠️  MATCH${RESET} → $f  ${DIM}(version: ${version#*: })${RESET}"
                else
                    print "${RED}⚠️  MATCH${RESET} → $f"
                fi
            fi
        done
    else
        print "${DIM}Listing direct dependencies from all projects...${RESET}"
        local excl
        excl=$(exclude_args)
        # shellcheck disable=SC2086
        find ~ -name package.json $excl 2>/dev/null | while read -r pkg; do
            check_interrupt
            dir=$(dirname "$pkg")
            print "${DIM}Project:${RESET} $dir"
            timeout "$TIMEOUT" bash -c "cd \"$dir\" && npm ls --depth=0" 2>/dev/null | tail -n +2 || true
        done
    fi

    print "${DIM}Global packages across nvm + mise...${RESET}"
    if [ -d "${NVM_DIR:-$HOME/.nvm}" ]; then
        nvm_dir="${NVM_DIR:-$HOME/.nvm}"
        for ver in "$nvm_dir"/versions/node/*; do
            check_interrupt
            [ -d "$ver" ] || continue
            ver_name=$(basename "$ver")
            echo "→ nvm $ver_name"
            timeout "$TIMEOUT" "$ver_name/bin/node" -v 2>/dev/null || true
            timeout "$TIMEOUT" "$ver_name/bin/npm" ls -g --depth=0 2>/dev/null | tail -n +2 || true
        done
    fi
    if command -v mise >/dev/null 2>&1; then
        for ver in $(timeout "$TIMEOUT" mise ls node --installed 2>/dev/null | awk '{print $1}'); do
            check_interrupt
            echo "→ mise $ver"
            timeout "$TIMEOUT" mise exec "node@$ver" -- npm ls -g --depth=0 2>/dev/null | tail -n +2 || true
        done
    fi
}

detect_ide_extensions() {
    print "${BOLD}→ IDE Extensions${RESET}"
    local home="$HOME"
    for dir in \
        "$home/.vscode/extensions" \
        "$home/.vscode-oss/extensions" \
        "$home/.cursor/extensions" \
        "$home/.config/Code/User/extensions"; do
    
        [ -d "$dir" ] || continue
        print "   📂 $dir"
        find "$dir" -mindepth 1 -maxdepth 1 -type d | while read -r ext; do
            print "      📦 $(basename "$ext")"
        done
    done
}

detect_ai_agents() {
    print "${BOLD}→ AI Coding Agents & Tools${RESET}"
    local tools=("claude" "cursor" "aider" "copilot" "windsurf" "zed" "ollama" "lm-studio" "codeium" "code")
    for t in "${tools[@]}"; do
        if command -v "$t" >/dev/null 2>&1; then
            ver=$("$t" --version 2>/dev/null | head -1 || echo "installed")
            print "   🤖 $t → $ver"
        fi
    done
    for d in ~/.claude ~/.cursor ~/.aider ~/.config/zed ~/.codeium ~/.vscode ~/.vscode-oss; do
        [ -d "$d" ] && print "   📁 Config: $d"
    done
}

# Optional hook for extra detectors (used by --add-detector)
# run_extra_detectors() {
#     # This function can be overridden by sourced detector files
#     true
# }

run_extra_detectors() {
    # This function is now safe: every detector registers its own run function
    # by appending to this array.
    for func in "${EXTRA_DETECTOR_FUNCTIONS[@]:-}"; do
        [ -n "$func" ] && "$func" 2>/dev/null || true
    done
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    if [ "$DRY_RUN" = true ]; then
        print "${BOLD}Dry run - would scan:${RESET}"
        [ "$ENABLE_NODE" = true ] && print "  • Node.js packages (npm/pnpm/bun/yarn + nvm/mise)"
        [ "$ENABLE_IDE" = true ] && print "  • IDE extensions"
        [ "$ENABLE_AI" = true ] && print "  • AI coding agents"
        [ -n "$PACKAGE_NAME" ] && print "  • Package: $PACKAGE_NAME${PACKAGE_VERSION:+" (version: $PACKAGE_VERSION)"}"
        [ ${#SEARCH_PATHS[@]} -gt 0 ] && print "  • Search paths: ${SEARCH_PATHS[*]}"
        [ ${#EXCLUDE_DIRS[@]} -gt 0 ] && print "  • Excluding: ${EXCLUDE_DIRS[*]}"
        print "\n${GREEN}✅ Dry run complete.${RESET}"
        exit 0
    fi

    print "${BOLD}DevGuard Scanner${RESET} | $(uname -s) | User: $USER"
    echo

    [[ "$ENABLE_NODE" == true ]] && scan_node
    [[ "$ENABLE_IDE" == true ]] && detect_ide_extensions
    [[ "$ENABLE_AI" == true ]] && detect_ai_agents
    run_extra_detectors   # ← calls any loaded detectors

    if [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "{\"tool\":\"devguard\",\"package\":\"$PACKAGE_NAME\",\"status\":\"complete\"}"
    else
        print "\n${GREEN}✅ Scan complete.${RESET}"
        print "${DIM}Run with --help for full options${RESET}"
    fi
}

main