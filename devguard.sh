#!/usr/bin/env bash
# =============================================================================
# DevGuard Scanner - Security-focused developer environment scanner
# Modular design: extra detectors can be loaded with --add-detector
# =============================================================================

set -Euo pipefail
shopt -s inherit_ubsan 2>/dev/null || true

# ------------------------------ CONFIGURATION --------------------------------
readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_VERSION="1.0.0"
readonly CONFIG_FILE="${HOME}/.devguardrc"
readonly CACHE_DIR="${HOME}/.cache/devguard"
readonly CACHE_TTL=3600  # 1 hour cache TTL

declare -g INTERRUPTED=false
declare -g EXIT_CODE=0

# ------------------------------ EXIT CODES ---------------------------------
readonly EXIT_OK=0
readonly EXIT_INTERRUPTED=130
readonly EXIT_INVALID_INPUT=2
readonly EXIT_NOT_FOUND=3

# ------------------------------ COLOR DEFINITIONS -------------------------
declare -g B='' D='' G='' R='' Y='' X=''
setup_colors() {
    if [[ "${NO_COLOR:-}" ]] || [[ "${COLOR_MODE:-auto}" == "never" ]]; then
        B='' D='' G='' R='' Y='' X=''
    else
        B='\033[1m'; D='\033[2m'; G='\033[32m'; R='\033[31m'; Y='\033[33m'; X='\033[0m'
    fi
}
setup_colors
readonly -f setup_colors

# ------------------------------ SIGNAL HANDLING ----------------------------
trap_handler() {
    local sig="$1"
    INTERRUPTED=true
    printf '%b\n' "${Y}⚠ Scan interrupted by signal ($sig). Cleaning up...${X}" >&2
    exit $EXIT_INTERRUPTED
}
trap 'trap_handler INT' INT
trap 'trap_handler TERM' TERM

check_interrupt() {
    [[ "$INTERRUPTED" == true ]] && exit $EXIT_INTERRUPTED
}

# ------------------------------ CLI DEFAULTS ------------------------------
PACKAGE_NAME=""
PACKAGE_VERSION=""
ENABLE_NODE=true
ENABLE_IDE=true
ENABLE_AI=true
OUTPUT_FORMAT="pretty"
QUIET=false
COLOR_MODE="auto"
TIMEOUT_SECS=30
DRY_RUN=false
SCAN_ALL_MODE=false
LIMIT_COUNT=0
EXCLUDE_DIRS=()
SEARCH_PATHS=()
EXTRA_DETECTORS=()
EXTRA_DETECTOR_FUNCTIONS=()

# ------------------------------ UTILITY FUNCTIONS ------------------------
emit() {
    [[ "$QUIET" == true ]] && return
    printf '%b\n' "$*"
}

die() {
    EXIT_CODE=$1
    shift
    printf '%b\n' "${R}Error: $*${X}" >&2
    exit "$EXIT_CODE"
}

# Simple progress spinner for long operations
spinner() {
    [[ "$QUIET" == true ]] && return
    local pid=$1
    local message="${2:-Processing...}"
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  %s " "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf " %-50s\n" "✓ $message"
}

# Parallel find helper - use xargs/parallel for better performance
parallel_find() {
    local search_root="$1"
    local pattern="$2"
    local exclude_args="$3"

    if command -v parallel >/dev/null 2>&1; then
        # Use GNU parallel for maximum performance
        find "$search_root" -type f \( $pattern \) $exclude_args -print0 2>/dev/null | parallel -0 -j+0 --no-notice echo
    elif command -v xargs >/dev/null 2>&1; then
        # Use xargs for parallelism
        find "$search_root" -type f \( $pattern \) $exclude_args -print0 2>/dev/null | xargs -0 -n1 -P4 echo
    else
        # Fallback to regular find
        find "$search_root" -type f \( $pattern \) $exclude_args 2>/dev/null
    fi
}

# Cache management functions
ensure_cache_dir() {
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
}

cache_key() {
    local content="$1"
    printf '%s' "$content" | sha256sum | cut -d' ' -f1
}

is_cache_valid() {
    local cache_file="$1"
    [[ -f "$cache_file" ]] && [[ $(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) )) -lt $CACHE_TTL ]]
}

read_cache() {
    local cache_file="$1"
    [[ -f "$cache_file" ]] && cat "$cache_file"
}

write_cache() {
    local cache_file="$1"
    ensure_cache_dir
    cat > "$cache_file"
}

# ------------------------------ CLI PARSING -----------------------------
parse_cli() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --package)         PACKAGE_NAME="$2"; shift 2 ;;
            --version)         PACKAGE_VERSION="$2"; shift 2 ;;
            --enable-node|--node)    ENABLE_NODE=true; shift ;;
             --disable-node|--no-node) ENABLE_NODE=false; shift ;;
             --enable-ide|--ide)      ENABLE_IDE=true; shift ;;
             --disable-ide|--no-ide)  ENABLE_IDE=false; shift ;;
             --enable-ai|--ai)        ENABLE_AI=true; shift ;;
             --disable-ai|--no-ai)    ENABLE_AI=false; shift ;;
            --add-detector)     EXTRA_DETECTORS+=("$2"); shift 2 ;;
            --quiet)            QUIET=true; shift ;;
            --timeout)         TIMEOUT_SECS="$2"; shift 2 ;;
            --color)           COLOR_MODE="$2"; shift 2 ;;
            --json)             OUTPUT_FORMAT="json"; shift ;;
            --exclude-dir)      EXCLUDE_DIRS+=("$2"); shift 2 ;;
            --search-path)      SEARCH_PATHS+=("$2"); shift 2 ;;
            --dry-run)         DRY_RUN=true; shift ;;
            --all|--scan-all)  SCAN_ALL_MODE=true; shift ;;
            --limit)           LIMIT_COUNT="$2"; shift 2 ;;
            -h|--help)
                cat <<HELP
${B}DevGuard Scanner${X} v${SCRIPT_VERSION}

${B}Usage:${X} $SCRIPT_NAME [options]

${B}Options:${X}
  --package NAME          Package name to search for
  --version REGEX        Version regex (optional)
  --enable-node, --node  Enable Node.js scanning (default)
  --disable-node, --no-node  Disable Node.js scanning
  --enable-ide, --ide    Enable IDE extensions scanning (default)
  --disable-ide, --no-ide  Disable IDE extensions scanning
  --enable-ai, --ai      Enable AI tools scanning (default)
  --disable-ai, --no-ai  Disable AI tools scanning
  --add-detector FILE    Load extra detector script (repeatable)
  --quiet                Suppress progress messages
  --timeout SECS        Command timeout (default: 30)
  --color (auto|never)  Color output mode
  --json                Output JSON summary
  --exclude-dir DIR     Exclude directory (repeatable)
  --search-path DIR     Search directory (default: ~)
  --dry-run             Preview what would be scanned
  --all, --scan-all     Scan all projects
  --limit N             Limit projects to scan
  -h, --help            Show this help
HELP
                exit $EXIT_OK
                ;;
            *) die $EXIT_INVALID_INPUT "Unknown option: $1" ;;
        esac
    done
}

# Load config file if present
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

parse_cli "$@"

# ------------------------------ INPUT VALIDATION -------------------------
validate_package_name() {
    [[ -z "$1" ]] && return 0
    if [[ ! "$1" =~ ^[a-zA-Z0-9@._/-]+$ ]]; then
        die $EXIT_INVALID_INPUT "Invalid package name: $1" \
            "Package names may only contain letters, numbers, @ . _ - /"
    fi
}

if [[ -n "$PACKAGE_NAME" ]]; then
    validate_package_name "$PACKAGE_NAME"
fi

for detector in "${EXTRA_DETECTORS[@]:-}"; do
    [[ -n "$detector" && -f "$detector" ]] && source "$detector" && emit "${D}Loaded extra detector: $detector${X}"
done

# ------------------------------ DRY RUN MODE -----------------------------
handle_dry_run() {
    [[ "$DRY_RUN" != true ]] && return 1
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        local pkg_json=""
        [[ -n "$PACKAGE_NAME" ]] && pkg_json=",\"package\":\"$PACKAGE_NAME\""
        printf '{"tool":"devguard"%s,"status":"dry-run"}\n' "$pkg_json"
        exit $EXIT_OK
    fi
    
    emit "${B}Dry run - would scan:${X}"
    [[ "$ENABLE_NODE" == true ]] && emit "  • Node.js packages (npm/pnpm/bun/yarn + nvm/mise)"
    [[ "$ENABLE_IDE" == true ]] && emit "  • IDE extensions"
    [[ "$ENABLE_AI" == true ]] && emit "  • AI coding agents"
    [[ -n "$PACKAGE_NAME" ]] && emit "  • Package: $PACKAGE_NAME${PACKAGE_VERSION:+ (version: $PACKAGE_VERSION)}"
    [[ ${#SEARCH_PATHS[@]} -gt 0 ]] && emit "  • Search paths: ${SEARCH_PATHS[*]}"
    [[ ${#EXCLUDE_DIRS[@]} -gt 0 ]] && emit "  • Excluding: ${EXCLUDE_DIRS[*]}"
    [[ ${#EXTRA_DETECTORS[@]} -gt 0 ]] && emit "  • Extra detectors: ${EXTRA_DETECTORS[*]}"
    emit ""
    emit "${G}✅ Dry run complete.${X}"
    exit $EXIT_OK
}

handle_dry_run && exit $EXIT_OK

[[ "$SCAN_ALL_MODE" == true ]] && emit "${D}⚠ Full scan mode - press Ctrl+C to cancel${X}"

# ------------------------------ CORE DETECTORS -----------------------------

get_search_root() {
    if [[ ${#SEARCH_PATHS[@]} -gt 0 ]]; then
        printf '%s\n' "${SEARCH_PATHS[@]}"
    elif [[ -n "${SEARCH_PATH:-}" ]]; then
        printf '%s\n' "$SEARCH_PATH"
    else
        printf '%s\n' "$HOME"
    fi
}

build_exclude_args() {
    local result="-not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/Trash/*'"
    for dir in "${EXCLUDE_DIRS[@]:-}"; do
        [[ -n "$dir" ]] && result="$result -not -path '*/$dir/*'"
    done
    printf '%s' "$result"
}

scan_node_packages() {
    emit "${B}→ Node.js packages (npm/pnpm/bun/yarn + nvm/mise)${X}"
    
    local excl
    excl=$(build_exclude_args)
    local search_root
    search_root=$(get_search_root)
    
    if [[ -n "$PACKAGE_NAME" ]]; then
        local pattern
        if [[ -n "$PACKAGE_VERSION" ]]; then
            pattern="(${PACKAGE_NAME}[\"']?\s*:\s*[\"']?${PACKAGE_VERSION})|(${PACKAGE_NAME}@${PACKAGE_VERSION})|(\"version\"\s*:\s*[\"']?${PACKAGE_VERSION})"
            emit "${D}Searching for: $PACKAGE_NAME matching $PACKAGE_VERSION${X}"
        else
            pattern="${PACKAGE_NAME}"
            emit "${D}Searching for any $PACKAGE_NAME (showing version)${X}"
        fi
        
        # Use cached find results if available
        local cache_key_str="${search_root}|${excl}|package.json"
        local cache_file="$CACHE_DIR/$(cache_key "$cache_key_str")"

        if is_cache_valid "$cache_file"; then
            emit "${D}Using cached package.json locations${X}"
        else
            emit "${D}Scanning for package.json files...${X}"
            find $search_root -name package.json $excl 2>/dev/null | write_cache "$cache_file"
        fi

        while IFS= read -r pkg_file; do
            check_interrupt
            [[ -z "$pkg_file" ]] && continue
            grep -qE "$pattern" "$pkg_file" || continue

            local version
            if [[ -z "$PACKAGE_VERSION" ]]; then
                version=$(grep -oE "${PACKAGE_NAME}[^\"']*[\"']?\s*:\s*[\"']?[^\"',}]+" "$pkg_file" 2>/dev/null | head -1 || echo "unknown")
                emit "${R}⚠ MATCH${X} → $pkg_file ${D}(version: ${version#*: })${X}"
            else
                emit "${R}⚠ MATCH${X} → $pkg_file"
            fi
        done < <(read_cache "$cache_file")
    fi
    
    if [[ "$SCAN_ALL_MODE" == true ]]; then
        [[ "$LIMIT_COUNT" -gt 0 ]] && emit "${D}Listing direct dependencies (limited to $LIMIT_COUNT)...${X}"
        
        local count=0
        while IFS= read -r pkg_file; do
            check_interrupt
            [[ -z "$pkg_file" ]] && continue
            [[ "$LIMIT_COUNT" -gt 0 ]] && [[ "$count" -ge "$LIMIT_COUNT" ]] && break

            count=$((count + 1))
            local dir
            dir=$(dirname "$pkg_file")
            emit "${D}Project ($count):${X} $dir"
            timeout "$TIMEOUT_SECS" bash -c "cd \"$dir\" && npm ls --depth=0" 2>/dev/null | tail -n +2 || true
        done < <(read_cache "$cache_file")
    fi
    
    emit "${D}Global packages from nvm + mise...${X}"
    
    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
    if [[ -d "$nvm_dir" ]]; then
        for ver in "$nvm_dir"/versions/node/*; do
            check_interrupt
            [[ -d "$ver" ]] || continue
            local ver_name
            ver_name=$(basename "$ver")
            echo "→ nvm $ver_name"
            timeout "$TIMEOUT_SECS" "$ver_name/bin/node" -v 2>/dev/null || true
            timeout "$TIMEOUT_SECS" "$ver_name/bin/npm" ls -g --depth=0 2>/dev/null | tail -n +2 || true
        done
    fi
    
    if command -v mise >/dev/null 2>&1; then
        local mise_versions
        mise_versions=$(timeout "$TIMEOUT_SECS" mise ls node --installed 2>/dev/null) || true
        while IFS= read -r line; do
            local ver
            ver=$(echo "$line" | awk '{print $2}')
            [[ -z "$ver" ]] && continue
            check_interrupt
            echo "→ mise $ver"
            timeout "$TIMEOUT_SECS" mise exec "node@$ver" -- npm ls -g --depth=0 2>/dev/null | tail -n +2 || true
        done <<< "$mise_versions"
    fi
}

detect_ide_extensions() {
    emit "${B}→ IDE Extensions${X}"
    
    local -a ide_dirs=(
        "$HOME/.vscode/extensions"
        "$HOME/.vscode-oss/extensions"
        "$HOME/.cursor/extensions"
        "$HOME/.config/Code/User/extensions"
    )
    
    for dir in "${ide_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        emit "   📂 $dir"
        find "$dir" -mindepth 1 -maxdepth 1 -type d -printf '      📦 %f\n' 2>/dev/null || true
    done
}

detect_ai_tools() {
    emit "${B}→ AI Coding Agents & Tools${X}"
    
    local -a ai_tools=("claude" "cursor" "aider" "copilot" "windsurf" "zed" "ollama" "lm-studio" "codeium" "code")
    local -a ai_config_dirs=("~/.claude" "~/.cursor" "~/.aider" "~/.config/zed" "~/.codeium" "~/.vscode" "~/.vscode-oss")
    
    for tool in "${ai_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local ver
            ver=$("$tool" --version 2>/dev/null | head -1 || echo "installed")
            emit "   🤖 $tool → $ver"
        fi
    done
    
    for dir in "${ai_config_dirs[@]}"; do
        local expanded="${dir//\~/$HOME}"
        [[ -d "$expanded" ]] && emit "   📁 Config: $expanded"
    done
}

run_extra_detectors() {
    for func in "${EXTRA_DETECTOR_FUNCTIONS[@]:-}"; do
        [[ -n "$func" ]] && "$func" 2>/dev/null || true
    done
}

# ------------------------------ MAIN -----------------------------
main() {
    emit "${B}DevGuard Scanner${X} | $(uname -s) | User: $USER"
    echo
    
    [[ "$ENABLE_NODE" == true ]] && scan_node_packages
    [[ "$ENABLE_IDE" == true ]] && detect_ide_extensions
    [[ "$ENABLE_AI" == true ]] && detect_ai_tools
    run_extra_detectors
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        local pkg_json=""
        [[ -n "$PACKAGE_NAME" ]] && pkg_json=",\"package\":\"$PACKAGE_NAME\""
        echo "{\"tool\":\"devguard\"${pkg_json},\"status\":\"complete\"}"
    else
        emit ""
        emit "${G}✅ Scan complete.${X}"
        emit "${D}Run with --help for full options${X}"
    fi
    
    exit $EXIT_OK
}

main "$@"