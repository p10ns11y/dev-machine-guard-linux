# Versioning

## Why Does the Version Start at 1.8.1?

StepSecurity Dev Machine Guard version numbering starts at **v1.8.1** rather than v1.0.0. This is intentional.

The scanning engine in this project was originally developed as an internal enterprise tool (the "StepSecurity Device Agent") with versions progressing through v1.0.0 to v1.8.1. When we open-sourced the project, we chose to continue the version sequence rather than reset to v1.0.0, for two reasons:

1. **Enterprise continuity**: Enterprise customers already run v1.8.1. The open-source release shares the same codebase, so keeping the version aligned avoids confusion.

2. **Stability signal**: The 1.x version number reflects that this is a mature, production-tested tool — not a v0.x experiment.

## Versioning Scheme

Going forward, Dev Machine Guard follows [Semantic Versioning](https://semver.org/):

- **Major** (X.0.0): Breaking changes to CLI interface, output format, or data file schema
- **Minor** (1.X.0): New detections, new features, new output formats
- **Patch** (1.8.X): Bug fixes, database updates, documentation improvements

Releases are published via [GitHub Releases](https://github.com/step-security/dev-machine-guard/releases) with auto-generated changelogs.
