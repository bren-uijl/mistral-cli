# Mistral CLI

A practical Bash CLI to chat with Mistral models directly from your terminal.

## What was improved

- Reliable option parsing with `--help`, `--reset-history`, and `--no-banner`.
- API key support via `MISTRAL_API_KEY` (with fallback to `~/.mistral_key`).
- Better CLI UI with colored prompts, compact status header, and a live `Thinking...` spinner.
- Runtime tuning via flags and commands for:
  - temperature
  - max output tokens
  - timestamps
  - reasoning mode (`off|brief|full`)
- Local coding tools:
  - run shell commands locally (`/run`)
  - run Python snippets locally (`/py`)
  - attach local outputs to the next AI request (`/sendlocal`)
- Session commands for better control:
  - `/help`, `/clear`, `/history [n]`, `/status`
  - `/model <name>`, `/code on|off`
  - `/temperature <f>`, `/tokens <n>`, `/reasoning <mode>`
  - `/local on|off`, `/run <cmd>`, `/py <code>`, `/sendlocal`
  - `/retry`, `/quit`
- Better handling of empty/non-JSON/API error responses.
- Persistent chat history and safer request payload generation through temporary files.

## Installation

```bash
git clone https://github.com/bren-uijl/mistral-cli.git
cd mistral-cli
chmod +x mistral-cli.sh
source ./mistral-cli.sh
```

Tip: add `source /path/to/mistral-cli.sh` to your `.bashrc` or `.zshrc`.

## Usage

Start a chat session:

```bash
ai
```

### Options

```text
-m, --model <name>       Use a specific model
-c, --code               Enable code mode (model: codestral-latest)
-d, --directly           Execute generated Python immediately
    --temperature <f>    Set model temperature (0.0-2.0)
    --max-tokens <n>     Set max output tokens
    --reasoning <mode>   Reasoning mode: off|brief|full
    --local-tools        Enable local run tools (/run, /py)
    --timestamps         Show timestamps on assistant messages
    --reset-history      Clear local history before startup
    --no-banner          Skip startup logs/banner
-h, --help               Show help
```

### Environment variables

- `MISTRAL_API_KEY`: API key from environment (recommended for CI/servers).
- `MISTRAL_KEY_FILE`: Key file path (default: `~/.mistral_key`).
- `AI_HISTORY_FILE`: History file path (default: `~/.ai_history.json`).
- `AI_MAX_HISTORY`: Number of stored history entries (default: `20`).
- `AI_TEMPERATURE`: Default temperature (default: `0.7`).
- `AI_MAX_TOKENS`: Default max output tokens (default: `1024`).
- `AI_REASONING`: Default reasoning mode (`off|brief|full`).
- `AI_TIMESTAMPS`: `true`/`false` assistant timestamps.

## Local execution safety note

`/run` and `/py` execute commands on your own machine and can change files. They are disabled by default and only work after enabling local tools (`--local-tools` or `/local on`).

## Requirements

- Bash
- Python 3
- curl
- Mistral API key

## Security

- If `MISTRAL_API_KEY` is not used, the API key is stored locally with `600` permissions.
- Chat history is stored locally in JSON format.
