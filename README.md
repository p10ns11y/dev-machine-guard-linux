# DevGuard Probe

![DevGaurd](/devguard-grokenhanced-best.png)

Clean, fast, and modular developer environment inspector for **Arch Linux + macOS**. It **inspects** your Node.js dependencies (npm, pnpm, bun, yarn), nvm/mise versions, IDE extensions (including VS Code OSS), AI coding agents & tools, **analyzes**, lists dependencies, *detects* tools, and even **looks into** git history of lockfiles.

### Features

- Node.js dependency scanning (npm, pnpm, bun, yarn)
- Full support for nvm and mise
- IDE extensions detection (including VS Code OSS)
- AI coding agents and tools
- Optional Git history analysis for lockfiles
- Highly extensible via separate detector files

### Quick Install

```bash
# 1. Save the script
curl -fsSL -o devguard.sh https://raw.githubusercontent.com/p10ns11y/dev-machine-guard-linux/refs/heads/main/security-dev-machine-guard.sh

# 2. Make executable
chmod +x devguard.sh

# 3. Test
./devguard.sh --package axios
```

### Basic Usage Examples

```bash
# Basic package search
./devguard.sh --package axios

# Search with specific version
./devguard.sh --package axios --version "1\.14\.1|0\.30\.4"

# Include git history (recommended for security checks)
./devguard.sh --package axios --add-detector ./git-history-search.sh

# Run only specific sections
./devguard.sh --node
./devguard.sh --ide
./devguard.sh --ai
```

### Options

| Option              | Description                                  | Default |
|---------------------|----------------------------------------------|---------|
| --package NAME      | Package name to search for                   | —       |
| --version REGEX     | Version regex (optional)                     | —       |
| --node / --no-node  | Enable/disable Node.js scanning              | on      |
| --ide / --no-ide    | Enable/disable IDE extensions                | on      |
| --ai / --no-ai      | Enable/disable AI tools                      | on      |
| --add-detector FILE | Load extra detector script (can be repeated) | —       |
| --quiet             | Suppress progress messages                   | off     |
| -h, --help          | Show this help                               | —       |

### Show: How it works

![DevGaurd Search](/devguard-searching-packages.png)

![DevGaurd Git Histroy](/devguard-git-history-search.png)


### About this project

Inspired by [StepSecurity Dev Machine Guard](https://github.com/step-security/dev-machine-guard).


This version has been vastly pivoted and simplified for better maintainability:

- 100% local — no telemetry, no backend, no cloud login
- Extremely clean and modular code
- Core script remains lightweight and readable
- Extra features (like git history) are loaded dynamically via --add-detector

Designed for developers who want a trustworthy, lightweight scanner without any bloat.