# Contributing to StepSecurity Dev Machine Guard

Thank you for your interest in contributing! Dev Machine Guard is an open-source project by [StepSecurity](https://stepsecurity.io) and we welcome contributions from the community.

## Ways to Contribute

### Add a New Detection

To add detection for a new AI tool, IDE, or framework:

1. Open an issue using the [Feature Request](.github/ISSUE_TEMPLATE/feature_request.yml) template, or
2. Submit a PR modifying `stepsecurity-dev-machine-guard.sh`

**How to add a new IDE/desktop app:**

Find the `detect_ide_installations()` function and add an entry to the `apps` array:
```bash
"App Name|type_id|Vendor|/Applications/App.app|Contents/MacOS/binary|--version"
```

**How to add a new AI CLI tool:**

Find the `detect_ai_cli_tools()` function and add an entry to the `tools` array:
```bash
"tool-name|Vendor|binary1,binary2|~/.config-dir1,~/.config-dir2"
```

### Improve Documentation

Documentation lives in the `docs/` folder. Improvements, corrections, and new guides are always welcome.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/step-security/dev-machine-guard.git
   cd dev-machine-guard
   ```

2. Make the script executable:
   ```bash
   chmod +x stepsecurity-dev-machine-guard.sh
   ```

3. Run locally:
   ```bash
   # Pretty output with progress messages
   ./stepsecurity-dev-machine-guard.sh --verbose

   # JSON output
   ./stepsecurity-dev-machine-guard.sh --json

   # HTML report
   ./stepsecurity-dev-machine-guard.sh --html report.html
   ```

## Code Style

- The script must pass [ShellCheck](https://www.shellcheck.net/) (our CI runs it on every PR)
- Follow the existing code patterns (section headers, function naming, JSON construction)
- Use `print_progress` for status messages (they respect the `--verbose` flag)
- Use `print_error` for error messages (always shown)

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b add-new-tool-detection`)
3. Make your changes
4. Test locally: `./stepsecurity-dev-machine-guard.sh --verbose`
5. Ensure ShellCheck passes: `shellcheck stepsecurity-dev-machine-guard.sh`
6. Submit a PR using our [PR template](.github/pull_request_template.md)

## Reporting Issues

- **Bugs**: Use the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml) template
- **Features**: Use the [Feature Request](.github/ISSUE_TEMPLATE/feature_request.yml) template
- **Security vulnerabilities**: See [SECURITY.md](SECURITY.md)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold this code.

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
