#!/bin/bash
# =============================================================================
# DevGuard Scanner - Clean, Modular, Extensible Edition
# Now includes `code` (VS Code CLI) in AI Coding Agents & Tools
# & includes yarn.lock in the search (classic + Berry)
# Scans ~/.vscode-oss/extensions too
# Shows actual version when --package is used without --version
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

while [[ $# -gt 0 ]]; do
    case $1 in
        --package)     PACKAGE_NAME="$2"; shift 2 ;;
        --version)     PACKAGE_VERSION="$2"; shift 2 ;;
        --node)        ENABLE_NODE=true; shift ;;
        --no-node)     ENABLE_NODE=false; shift ;;
        --ide)         ENABLE_IDE=true; shift ;;
        --no-ide)      ENABLE_IDE=false; shift ;;
        --ai)          ENABLE_AI=true; shift ;;
        --no-ai)       ENABLE_AI=false; shift ;;
        --json)        OUTPUT_FORMAT="json"; shift ;;
        --quiet)       QUIET=true; shift ;;
        -h|--help)
            cat <<EOF
DevGuard Scanner

Usage: $0 [options]

Options:
  --package NAME          Package name to search for
  --version REGEX         Specific version regex (optional)
  --node / --no-node      Enable/disable Node.js scanning
  --ide / --no-ide        Enable/disable IDE extensions
  --ai / --no-ai          Enable/disable AI tools
  --json                  JSON output
  --quiet                 Suppress messages
  -h, --help              Show help
EOF
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ----------------------------- COLORS ----------------------------------------
BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[32m'; RED='\033[31m'; RESET='\033[0m'
print() { [ "$QUIET" = true ] && return; echo -e "$*"; }

# =============================================================================
# MODULAR DETECTORS
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

        find ~ -type f \( \
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
            (cd "$dir" && npm ls --depth=0 2>/dev/null | tail -n +2) || true
        done
    fi

    print "${DIM}Global packages across nvm + mise...${RESET}"
    if command -v nvm >/dev/null 2>&1; then
        for ver in $(nvm ls --no-colors 2>/dev/null | grep -E 'v[0-9]' | awk '{print $1}'); do
            nvm use "$ver" --silent 2>/dev/null || continue
            echo "→ nvm $ver"
            npm ls -g --depth=0 2>/dev/null | tail -n +2 || true
        done
    fi
    if command -v mise >/dev/null 2>&1; then
        for ver in $(mise ls node --installed 2>/dev/null | awk '{print $1}'); do
            echo "→ mise $ver"
            mise exec "node@$ver" -- npm ls -g --depth=0 2>/dev/null | tail -n +2 || true
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

    for d in ~/.claude ~/.cursor ~/.aider ~/.config/zed ~/.codeium ~/.vscode-oss; do
        [ -d "$d" ] && print "   📁 Config: $d"
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

    print "\n${GREEN}✅ Scan complete.${RESET}"
    print "${DIM}Run with --help for full options${RESET}"
}

main