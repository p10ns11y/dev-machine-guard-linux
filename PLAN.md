# DevGuard Scanner - Plans

## Current Status
- **Rust Version**: Core functionality implemented, compiles successfully, handles config loading (including BOM stripping), and performs package scanning with progress output.
- **Go Version**: Refactored for security, includes AI tools/agents detection.
- **Ada/SPARK Version**: Initial implementation added, requires GNAT toolchain for compilation and formal verification.
- **Zig Version**: Initial implementation added, requires Zig toolchain for compilation.

## Next Steps (Tomorrow)
- Test all language versions locally: Compile, run basic commands (`--help`, `--package lodash --version 4`), and verify output.
- Fix any compilation errors (e.g., missing dependencies in Ada/SPARK, Zig stdlib issues).
- Validate config handling across versions (BOM, invalid JSON fallbacks).
- Add unit tests or basic integration tests for each language.
- Enhance features if needed: More detector types, better error messages, recursive scanning limits.
- Document build/install instructions per language.
- Consider CI/CD setup for automated testing.

## Long-Term Goals
- Achieve formal verification for Ada/SPARK version.
- Benchmark performance and security across languages.
- Extend to other platforms (macOS, Windows) if needed.
- Open-source release with contributor guidelines.

## Blockers
- Toolchain availability (GNAT for Ada/SPARK, Zig 0.10+).
- Runtime policy restrictions on shell execution for testing.