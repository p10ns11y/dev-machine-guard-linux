# StepSecurity Dev Machine Guard — Scan Coverage

This document catalogs everything Dev Machine Guard detects. Contributions to expand coverage are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## IDEs & AI Desktop Apps

| Application           | Vendor    | Detection Method            | Version Extraction              |
|-----------------------|-----------|-----------------------------|---------------------------------|
| Visual Studio Code    | Microsoft | `/Applications/Visual Studio Code.app` | Binary `--version`     |
| Cursor                | Cursor    | `/Applications/Cursor.app`  | Binary `--version`              |
| Windsurf              | Codeium   | `/Applications/Windsurf.app`| Binary `--version`              |
| Antigravity           | Google    | `/Applications/Antigravity.app` | Binary `--version`          |
| Zed                   | Zed       | `/Applications/Zed.app`     | `Info.plist`                    |
| Claude Desktop        | Anthropic | `/Applications/Claude.app`  | `Info.plist`                    |
| Microsoft Copilot     | Microsoft | `/Applications/Copilot.app` | `Info.plist`                    |

## AI CLI Tools

| Tool                  | Vendor    | Binary Names                | Config Directories              |
|-----------------------|-----------|-----------------------------|---------------------------------|
| Claude Code           | Anthropic | `claude`                    | `~/.claude`                     |
| Codex                 | OpenAI    | `codex`                     | `~/.codex`                      |
| Gemini CLI            | Google    | `gemini`                    | `~/.gemini`                     |
| Amazon Q / Kiro CLI   | Amazon    | `kiro-cli`, `kiro`, `q`     | `~/.q`, `~/.kiro`, `~/.aws/q`  |
| GitHub Copilot CLI    | Microsoft | `copilot`, `gh-copilot`     | `~/.config/github-copilot`      |
| Microsoft AI Shell    | Microsoft | `aish`, `ai`                | `~/.aish`                       |
| Aider                 | OpenSource| `aider`                     | `~/.aider`                      |
| OpenCode              | OpenSource| `opencode`                  | `~/.config/opencode`            |

## General-Purpose AI Agents

| Agent                 | Vendor    | Detection Paths             |
|-----------------------|-----------|-----------------------------|
| OpenClaw              | OpenSource| `~/.openclaw`               |
| ClawdBot              | OpenSource| `~/.clawdbot`               |
| MoltBot               | OpenSource| `~/.moltbot`                |
| MoldBot               | OpenSource| `~/.moldbot`                |
| GPT-Engineer          | OpenSource| `~/.gpt-engineer`           |
| Claude Cowork         | Anthropic | Claude Desktop v0.7.0+      |

## AI Frameworks & Runtimes

| Framework             | Binary    | Notes                       |
|-----------------------|-----------|-----------------------------|
| Ollama                | `ollama`  | Checks if process is running|
| LocalAI               | `local-ai`| Checks if process is running|
| LM Studio             | `lm-studio` or `/Applications/LM Studio.app` | GUI app detection |
| Text Generation WebUI | `textgen` | Checks if process is running|

## MCP Configuration Sources

| Source                | Config Path                                         | Vendor    |
|-----------------------|-----------------------------------------------------|-----------|
| Claude Desktop        | `~/Library/Application Support/Claude/claude_desktop_config.json` | Anthropic |
| Claude Code           | `~/.claude/settings.json`                           | Anthropic |
| Cursor                | `~/.cursor/mcp.json`                                | Cursor    |
| Windsurf              | `~/.codeium/windsurf/mcp_config.json`               | Codeium   |
| Antigravity           | `~/.gemini/antigravity/mcp_config.json`             | Google    |
| Zed                   | `~/.config/zed/settings.json`                       | Zed       |
| Open Interpreter      | `~/.config/open-interpreter/config.yaml`            | OpenSource|
| Codex                 | `~/.codex/config.toml`                              | OpenAI    |

## IDE Extensions

| IDE         | Extensions Directory           | Format                        |
|-------------|--------------------------------|-------------------------------|
| VS Code     | `~/.vscode/extensions`         | `publisher.name-version`      |
| Cursor      | `~/.cursor/extensions`         | `publisher.name-version`      |

## Node.js Package Scanning (Optional)

| Package Manager | Global Packages | Project Packages              |
|-----------------|-----------------|-------------------------------|
| npm             | `npm list -g`   | `npm ls --json` per project   |
| yarn            | `yarn global list` | `yarn list --json` per project |
| pnpm            | `pnpm list -g`  | `pnpm ls --json` per project  |
| bun             | N/A             | `bun pm ls` per project       |

Node.js scanning is **off by default** in community mode (it can be slow). Enable with `--enable-npm-scan`.

---

## Adding New Detections

Want to add detection for a new tool, IDE, or framework? See [docs/adding-detections.md](docs/adding-detections.md) or open a [New Detection issue](.github/ISSUE_TEMPLATE/new_detection.yml).
