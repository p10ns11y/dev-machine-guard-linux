#!/bin/bash
# =============================================================================
# DevGuard Scanner - Core (lean & classy)
# Modular design: extra detectors can be loaded with --add-detector
# =============================================================================

set -euo pipefail

# ----------------------------- CLI PARSING -----------------------------------
PACKAGE_NAME=""
PACKAGE_VERSION=""
ENABLE_NODE=true
ENABLE_IDE=true
ENABLE_AI=true
OUTPUT_FORMAT="pretty"
QUIET=false
COLOR_MODE="auto"
TIMEOUT=30
DRY_RUN=false
EXCLUDE_DIRS=()
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
        BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[32m'; RED='\033[31m'; RESET='\033[0m'
    fi
}
apply_colors
print() { [ "$QUIET" = true ] && return; echo -e "$*"; }

# ----------------------------- INPUT VALIDATION ------------------------------
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

        find ~ -type f \(  \
            -name package-lock.json -o \
            -name pnpm-lock.yaml -o \
            -name bun.lockb -o \
            -name yarn.lock -o \
            -name package.json \
        \) -not -path "*/Trash/*" -not -path "*/node_modules/*" 2>/dev/null | while read -r f; do

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
        find ~ -name package.json -not -path "*/node_modules/*" -not -path "*/Trash/*" 2>/dev/null | while read -r pkg; do
            dir=$(dirname "$pkg")
            print "${DIM}Project:${RESET} $dir"
            timeout "$TIMEOUT" bash -c "cd \"$dir\" && npm ls --depth=0" 2>/dev/null | tail -n +2 || true
        done
    fi

    print "${DIM}Global packages across nvm + mise...${RESET}"
    if command -v nvm >/dev/null 2>&1; then
        for ver in $(timeout "$TIMEOUT" nvm ls --no-colors 2>/dev/null | grep -E 'v[0-9]' | awk '{print $1}'); do
            timeout "$TIMEOUT" nvm use "$ver" --silent 2>/dev/null || continue
            echo "→ nvm $ver"
            timeout "$TIMEOUT" npm ls -g --depth=0 2>/dev/null | tail -n +2 || true
        done
    fi
    if command -v mise >/dev/null 2>&1; then
        for ver in $(timeout "$TIMEOUT" mise ls node --installed 2>/dev/null | awk '{print $1}'); do
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