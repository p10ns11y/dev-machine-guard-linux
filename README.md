# DevGuard Scanner

A clean, fast, modular developer environment scanner for **Linux + macOS**.

Scans:
- Node.js dependencies (npm, pnpm, bun, yarn)
- nvm + mise Node versions
- IDE extensions (including VS Code OSS)
- AI coding agents and tools

### Quick Start

```bash
# 1. Save the script
curl -fsSL -o devguard.sh https://raw.githubusercontent.com/p10ns11y/dev-machine-guard-linux/refs/heads/main/security-dev-machine-guard.sh

# 2. Make executable
chmod +x devguard.sh

# 3. Run it
./devguard.sh
```

### About this project
Inspired by [StepSecurity Dev Machine Guard](https://github.com/step-security/dev-machine-guard).

This version has vastly pivoted and is deliberately much simpler:

100% local (no telemetry, no enterprise backend, no cloud login)
Extremely clean and modular shell code (under 200 lines)

Focused exactly on what you need: Node.js package scanning + IDE extensions + AI tools

Easy to read, extend, and maintain

Works perfectly on Arch Linux (including ~/.vscode-oss) + macOS

Made for developers who want a lightweight, trustworthy scanner without any extra complexity.