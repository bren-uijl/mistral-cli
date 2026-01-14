# Mistral CLI

A powerful and interactive Bash-based CLI tool to chat with Mistral AI models directly from your terminal. It features built-in chat history, a specialized "Code Mode," and the ability to execute generated Python code on the fly.

## Features

Interactive Chat: Chat with AI without leaving your command line.

Code Mode: Use the -c flag to switch to codestral-latest for programming tasks.

Auto-Execution: Generated Python snippets (including Matplotlib plots) can be executed directly from the prompt.

Secure API Storage: The script prompts for your API key once and saves it securely in a local file.

Terminal Interface: Includes a sleek rainbow-colored ASCII intro and real-time loading logs.

## Installation

### Clone the repository:

`git clone https://github.com/bren-uijl/mistral-cli.git`

`cd mistral-cli`


### Make the script executable:

`chmod +x mistral_chat.sh`


### Add it to your shell (Optional):
You can source the file in your ~/.bashrc or ~/.zshrc to make the ai command available everywhere:

`source /path/to/mistral_chat.sh`


## Usage

### Simply type ai to start the session:

`ai`


## Flags and Arguments:

`ai -c` or `ai --code`: Enables Code Mode. Uses the Codestral model and hides long code blocks for a cleaner chat interface.

`ai -d` or `ai --directly`: Executes generated code immediately without asking for confirmation.

`ai -m [model-name]`: Manually select a specific Mistral model (e.g., mistral-large-latest).

## API Key Setup:

### On your first run, the script will ask:
"Enter your Mistral API-key:"
Your key is saved locally in `~/.mistral_key`. This file is ignored by Git to ensure your credentials are never uploaded.

## Prerequisites

### Bash (Git Bash, WSL, or Linux)

### Python 3 (required for JSON and code execution)

### Curl

### Mistral API Key (Get one at console.mistral.ai)

## Security and Privacy

### Your API key is stored in a hidden local file (~/.mistral_key) with restricted permissions (600).

### Chat history is stored locally in ~/.ai_history.json.

Powered by Mistral AI | Developed for the Terminal
