# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

See [VERSIONING.md](VERSIONING.md) for why the version starts at 1.8.1.

## [1.8.1] - 2026-03-10

First open-source release. The scanning engine was previously an internal enterprise tool (v1.0.0-v1.8.1) running in production. This release adds community mode for local-only scanning while keeping the enterprise codebase intact.

### Added
- **Community mode** with three output formats: pretty terminal, JSON, and HTML report
- **AI agent and CLI tool detection**: Claude Code, Codex, Gemini CLI, Kiro, Aider, OpenCode, and more
- **General-purpose AI agent detection**: OpenClaw, ClawdBot, GPT-Engineer, Claude Cowork
- **AI framework detection**: Ollama, LM Studio, LocalAI, Text Generation WebUI
- **MCP server config auditing** across Claude Desktop, Claude Code, Cursor, Windsurf, Antigravity, Zed, Open Interpreter, and Codex
- **IDE extension scanning** for VS Code and Cursor (with publisher, version, and install date)
- **Node.js package scanning** for npm, yarn, pnpm, and bun (opt-in in community mode)
- CLI flags: `--pretty`, `--json`, `--html FILE`, `--verbose`, `--enable-npm-scan`, `--color=WHEN`
- Documentation: community mode guide, enterprise mode guide, MCP audit guide, adding detections guide, reading scan results guide
- GitHub issue templates for bugs, feature requests, and new detections
- ShellCheck CI workflow with Harden-Runner

### Changed
- Enterprise config variables are now clearly labeled and placed below the community-facing header
- Progress messages suppressed by default in community mode (enable with `--verbose`)
- Node.js scanning off by default in community mode (enable with `--enable-npm-scan`)

### Enterprise (unchanged from v1.8.1)
- `install`, `uninstall`, and `send-telemetry` commands
- Launchd scheduling (LaunchDaemon for root, LaunchAgent for user)
- S3 presigned URL upload with backend notification
- Execution log capture and base64 encoding
- Instance locking to prevent concurrent runs

[1.8.1]: https://github.com/step-security/dev-machine-guard/releases/tag/v1.8.1
