# DevGuard Scanner - Technical Details

## Overview
DevGuard Scanner is a modular developer environment security scanner for Linux and macOS. It detects vulnerable or outdated dependencies in Node.js projects, IDE extensions, AI tools/agents, and more. It supports extensible detectors and optional Git history analysis.

## Language Versions
Implemented in multiple languages for comparison of security and performance:

### Rust Version (`devguard.rs`)
- **Security**: Memory-safe, no GC, compile-time checks prevent overflows/null derefs.
- **Dependencies**: `serde_json`, `serde` (for config), standard library for filesystem.
- **Build**: `cargo build` (requires Rust 1.70+).
- **Config Handling**: JSON from `~/.devguardrc`, strips BOM, falls back to defaults on parse failure.
- **Scanning**: Recursively finds `package.json`, checks `dependencies`/`devDependencies` for matches.
- **Output**: Progress prints, matches with version info, or "No matches".

### Go Version (`devguard.go`)
- **Security**: Garbage-collected, bounds-checked arrays, no unsafe pointers.
- **Dependencies**: Standard library only (`os`, `filepath`, `encoding/json`).
- **Build**: `go build devguard.go`.
- **Features**: Includes AI tools/agents detection (e.g., `.openai`, `.agents` dirs and configs).
- **Config**: Same JSON format.

### Ada/SPARK Version (`devguard.adb`)
- **Security**: Formal verification with GNATprove (proves absence of runtime errors like overflows).
- **Dependencies**: GNATCOLL.JSON, GNAT.Regexp.
- **Build**: `gnatmake devguard.adb` (requires GNAT Pro or Community).
- **Verification**: Run `gnatprove --mode=flow` for proof of safety.
- **Limitations**: JSON parsing less mature than Rust/Go.

### Zig Version (`devguard.zig`)
- **Security**: Manual memory, but comptime checks and allocator safety prevent leaks/crashes.
- **Dependencies**: Zig stdlib.
- **Build**: `zig build-exe devguard.zig`.
- **Config**: Uses Zig's JSON parser.

## Config Format
- **Path**: `~/.devguardrc`
- **Format**: JSON
- **Fields**:
  - `timeout_secs` (number): Scan timeout (default 30).
  - `search_paths` (array of strings): Paths to scan (default ["/home/sustainableabundance"]).

## Usage Examples
- `./target/debug/devguard --help`: Show options.
- `./target/debug/devguard --all`: Scan all types.
- `./target/debug/devguard --package lodash --version 4`: Check for lodash v4.

## Architecture
- **Modular Detectors**: Each detector (e.g., package scanner) is a function.
- **Error Handling**: Graceful fallbacks, no panics.
- **Extensibility**: Add new detectors by implementing a trait/function.

## Security Focus
- No shell injection (direct filesystem APIs).
- Input validation on all user data.
- No network access.
- Safe languages prevent common vulns (e.g., buffer overflows in C).

## Performance
- Rust: Fast, low overhead.
- Go: Good concurrency potential.
- Ada/SPARK: Slower due to proofs, but ultra-safe.
- Zig: Fast, C-like but safer.

## Testing
- Manual: Build, run commands, check output.
- Future: Add tests for parsing, scanning logic.