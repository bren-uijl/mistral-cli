ai() {
    local key_file="${MISTRAL_KEY_FILE:-$HOME/.mistral_key}"
    local history_file="${AI_HISTORY_FILE:-$HOME/.ai_history.json}"
    local code_file="${AI_CODE_FILE:-$HOME/.ai_code.py}"

    local selected_model="mistral-small-latest"
    local is_code_mode=false
    local direct_exec=false
    local reset_history=false
    local show_banner=true
    local max_history="${AI_MAX_HISTORY:-20}"
    local temperature="${AI_TEMPERATURE:-0.7}"
    local max_tokens="${AI_MAX_TOKENS:-1024}"
    local show_timestamps="${AI_TIMESTAMPS:-false}"
    local reasoning_mode="${AI_REASONING:-brief}"
    local local_tools=false

    local last_user_input=""
    local last_local_result=""
    local attach_local_once=false

    local B='\033[1m'
    local R='\033[0m'
    local C_INFO='\033[36m'
    local C_OK='\033[32m'
    local C_WARN='\033[33m'
    local C_ERR='\033[31m'
    local C_USER='\033[35m'

    _ai_print_header() {
        echo -e "${C_INFO}╭────────────────────────────────────────────────────────────╮${R}"
        echo -e "${C_INFO}│${R} ${B}Mistral CLI${R} model=${B}${selected_model}${R} code=${B}${is_code_mode}${R} think=${B}${reasoning_mode}${R} ${C_INFO}│${R}"
        echo -e "${C_INFO}│${R} temp=${B}${temperature}${R} tokens=${B}${max_tokens}${R} local_tools=${B}${local_tools}${R}          ${C_INFO}│${R}"
        echo -e "${C_INFO}╰────────────────────────────────────────────────────────────╯${R}"
    }

    _ai_spinner() {
        local pid="$1"
        local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while kill -0 "$pid" >/dev/null 2>&1; do
            local frame="${frames:i++%${#frames}:1}"
            echo -ne "\r${C_INFO}${frame} Thinking...${R}"
            sleep 0.08
        done
        echo -ne "\r\033[K"
    }

    _ai_usage() {
        cat <<'USAGE'
Usage: ai [options]

Options:
  -m, --model <name>       Use a specific model (default: mistral-small-latest)
  -c, --code               Enable code mode (forces model: codestral-latest)
  -d, --directly           Execute generated Python code immediately
      --temperature <f>    Set model temperature (0.0-2.0)
      --max-tokens <n>     Set max output tokens
      --reasoning <mode>   one of: off, brief, full (default: brief)
      --local-tools        Enable /run and /py local execution commands
      --timestamps         Show timestamps on assistant messages
      --reset-history      Clear local history before starting
      --no-banner          Skip startup banner and logs
  -h, --help               Show this help

Environment variables:
  MISTRAL_API_KEY          API key (preferred over key file)
  MISTRAL_KEY_FILE         Override key file path (default: ~/.mistral_key)
  AI_HISTORY_FILE          Override history file path (default: ~/.ai_history.json)
  AI_MAX_HISTORY           Number of turns stored (default: 20)
  AI_TEMPERATURE           Default sampling temperature (default: 0.7)
  AI_MAX_TOKENS            Default max output tokens (default: 1024)
  AI_REASONING             Default reasoning mode: off|brief|full
  AI_TIMESTAMPS            true/false for assistant timestamps
USAGE
    }

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -m|--model)
                [[ -z "${2:-}" ]] && echo "Error: --model requires a value." && return 1
                selected_model="$2"; shift 2 ;;
            -c|--code)
                selected_model="codestral-latest"; is_code_mode=true; shift ;;
            -d|--directly)
                direct_exec=true; shift ;;
            --temperature)
                [[ -z "${2:-}" ]] && echo "Error: --temperature requires a value." && return 1
                temperature="$2"; shift 2 ;;
            --max-tokens)
                [[ -z "${2:-}" ]] && echo "Error: --max-tokens requires a value." && return 1
                max_tokens="$2"; shift 2 ;;
            --reasoning)
                [[ -z "${2:-}" ]] && echo "Error: --reasoning requires a value." && return 1
                reasoning_mode="$2"; shift 2 ;;
            --local-tools)
                local_tools=true; shift ;;
            --timestamps)
                show_timestamps=true; shift ;;
            --reset-history)
                reset_history=true; shift ;;
            --no-banner)
                show_banner=false; shift ;;
            -h|--help)
                _ai_usage; return 0 ;;
            *)
                echo "Error: Unknown option '$1'."; _ai_usage; return 1 ;;
        esac
    done

    case "$reasoning_mode" in
        off|brief|full) ;;
        *) echo "Error: invalid reasoning mode '$reasoning_mode' (use off|brief|full)."; return 1 ;;
    esac

    if ! command -v curl >/dev/null 2>&1; then echo "Error: curl is required but not installed."; return 1; fi
    if ! command -v python >/dev/null 2>&1; then echo "Error: python is required but not installed."; return 1; fi

    local api_key="${MISTRAL_API_KEY:-}"
    if [[ -z "$api_key" && -f "$key_file" ]]; then
        api_key=$(tr -d '\r\n' < "$key_file")
    fi

    if [[ -z "$api_key" ]]; then
        echo -e "${C_WARN}[!] No API key found.${R}"
        echo -n "Please enter your Mistral API key (input hidden): "
        read -rs api_key
        echo

        [[ -z "$api_key" ]] && echo "Error: No key entered." && return 1
        [[ ${#api_key} -lt 20 ]] && echo "Error: The entered key does not appear valid (too short)." && return 1

        printf '%s\n' "$api_key" > "$key_file"
        chmod 600 "$key_file"
        echo "Saved API key to $key_file"
    fi

    if [[ "$reset_history" == true || ! -f "$history_file" ]]; then
        echo "[]" > "$history_file"
    fi

    if [[ "$show_banner" == true ]]; then
        local logs=(
            "\033[38;2;255;0;0m[!!] CRITICAL ERROR:\033[0m USER TOO AWESOME FOR STANDARD CHAT."
            "[!!] ATTEMPTING WORKAROUND... [\033[1;33mOK\033[0m]"
            "\033[38;2;255;0;0m[!!] WARNING: THIS TERMINAL MAY CONTAIN TRACES OF PUNNY JOKES.\033[0m"
            "[\033[32m▰▰▰▰▰▰▰▰▰▰\033[0m] 100% (\033[1;33mReady to chat!\033[0m)"
            "\033[38;2;255;0;0m[!!] JUST KIDDING! WELCOME.\033[0m"
        )
        for log in "${logs[@]}"; do echo -e "[$(date +'%H:%M:%S')] ${log}"; sleep 0.2; done
        echo
    fi

    _ai_print_header
    echo -e "${C_INFO}Type '/help' for local commands.${R}"

    while true; do
        echo -ne "${C_USER}you${R} ${B}>${R} "
        IFS= read -r user_input || break

        case "$user_input" in
            exit|quit|/exit|/quit)
                break ;;
            /help)
                cat <<'CMDS'
Local commands:
  /help                Show this help
  /clear               Clear stored chat history
  /history [n]         Show last n history entries (default: 6)
  /model <name>        Switch model during session
  /code on|off         Toggle code mode
  /temperature <f>     Set temperature (0.0-2.0)
  /tokens <n>          Set max output tokens
  /reasoning <mode>    Set reasoning mode: off|brief|full
  /local on|off        Enable/disable local execution tools
  /run <shell cmd>     Run a local shell command (needs local tools enabled)
  /py <python code>    Run local Python snippet (needs local tools enabled)
  /sendlocal           Attach last local output to next AI request
  /retry               Re-send last user message
  /status              Show current session config
  /quit                Exit
CMDS
                continue ;;
            /clear)
                echo "[]" > "$history_file"; echo "History cleared."; continue ;;
            /status)
                _ai_print_header
                echo "Direct execution: $direct_exec"
                echo "History file: $history_file"
                echo "Max history: $max_history"
                echo "Timestamps: $show_timestamps"
                [[ -n "$last_local_result" ]] && echo "Last local result: available" || echo "Last local result: none"
                continue ;;
            /history* )
                local count="${user_input#/history }"
                [[ "$count" == "/history" ]] && count=6
                [[ ! "$count" =~ ^[0-9]+$ ]] && count=6
                HISTORY_FILE="$history_file" COUNT="$count" python - <<'PY'
import json, os
hf=os.path.expanduser(os.environ['HISTORY_FILE'])
count=int(os.environ['COUNT'])
with open(hf,'r',encoding='utf-8') as f: h=json.load(f)
for i,m in enumerate(h[-count:],1):
    role=m.get('role','?')
    content=m.get('content','').replace('\n',' ')[:120]
    print(f"{i:02d}. {role}: {content}")
PY
                continue ;;
            /model\ *)
                selected_model="${user_input#/model }"
                echo -e "${C_OK}Model switched to:${R} $selected_model"
                continue ;;
            "/code on")
                is_code_mode=true; selected_model="codestral-latest"
                echo -e "${C_OK}Code mode enabled${R} (model: $selected_model)."
                continue ;;
            "/code off")
                is_code_mode=false
                echo -e "${C_WARN}Code mode disabled.${R}"
                continue ;;
            /temperature\ *)
                temperature="${user_input#/temperature }"
                echo -e "${C_OK}Temperature set to:${R} $temperature"
                continue ;;
            /tokens\ *)
                max_tokens="${user_input#/tokens }"
                echo -e "${C_OK}Max tokens set to:${R} $max_tokens"
                continue ;;
            /reasoning\ *)
                reasoning_mode="${user_input#/reasoning }"
                case "$reasoning_mode" in
                    off|brief|full) echo -e "${C_OK}Reasoning mode set to:${R} $reasoning_mode" ;;
                    *) echo -e "${C_ERR}Invalid reasoning mode. Use off|brief|full.${R}"; reasoning_mode="brief" ;;
                esac
                continue ;;
            "/local on")
                local_tools=true
                echo -e "${C_OK}Local tools enabled.${R}"
                continue ;;
            "/local off")
                local_tools=false
                echo -e "${C_WARN}Local tools disabled.${R}"
                continue ;;
            /run\ *)
                if [[ "$local_tools" != true ]]; then
                    echo -e "${C_WARN}Enable local tools first: /local on${R}"
                    continue
                fi
                local shell_cmd="${user_input#/run }"
                last_local_result=$(bash -lc "$shell_cmd" 2>&1)
                last_local_result=$(printf '%s' "$last_local_result" | tail -c 4000)
                echo -e "${C_OK}Local command output:${R}\n$last_local_result"
                continue ;;
            /py\ *)
                if [[ "$local_tools" != true ]]; then
                    echo -e "${C_WARN}Enable local tools first: /local on${R}"
                    continue
                fi
                local py_code="${user_input#/py }"
                last_local_result=$(python - <<PY 2>&1
$py_code
PY
)
                last_local_result=$(printf '%s' "$last_local_result" | tail -c 4000)
                echo -e "${C_OK}Local Python output:${R}\n$last_local_result"
                continue ;;
            /sendlocal)
                if [[ -z "$last_local_result" ]]; then
                    echo -e "${C_WARN}No local result available. Run /run or /py first.${R}"
                    continue
                fi
                attach_local_once=true
                echo -e "${C_OK}Will attach last local output to next request.${R}"
                continue ;;
            /retry)
                if [[ -z "$last_user_input" ]]; then
                    echo -e "${C_WARN}No previous user message to retry.${R}"
                    continue
                fi
                user_input="$last_user_input"
                echo -e "${C_INFO}Retrying last message...${R}"
                ;;
        esac

        [[ -z "$user_input" ]] && continue
        last_user_input="$user_input"

        local tmp_payload tmp_response
        tmp_payload=$(mktemp)
        tmp_response=$(mktemp)

        USER_INPUT="$user_input" \
        HISTORY_FILE="$history_file" \
        SELECTED_MODEL="$selected_model" \
        IS_CODE_MODE="$is_code_mode" \
        TEMPERATURE="$temperature" \
        MAX_TOKENS="$max_tokens" \
        REASONING_MODE="$reasoning_mode" \
        ATTACH_LOCAL_ONCE="$attach_local_once" \
        LAST_LOCAL_RESULT="$last_local_result" \
        python - <<'PY' > "$tmp_payload"
import json, os
h_file = os.path.expanduser(os.environ["HISTORY_FILE"])
with open(h_file, "r", encoding="utf-8") as f:
    history = json.load(f)

reasoning_mode = os.environ["REASONING_MODE"]
if reasoning_mode == "full":
    reasoning_instruction = "Include a clear reasoning section before the final answer."
elif reasoning_mode == "brief":
    reasoning_instruction = "Give a short reasoning summary before the final answer."
else:
    reasoning_instruction = "Do not include reasoning steps; provide concise answers."

if os.environ["IS_CODE_MODE"] == "true":
    system_content = (
        "You are a coding expert. If using matplotlib: use Agg and save figures to plot.png. "
        + reasoning_instruction
    )
else:
    system_content = (
        "You are a helpful chat assistant. Reply in English unless the user asks for another language. "
        "Use code blocks only when explicitly requested. " + reasoning_instruction
    )

messages = [{"role": "system", "content": system_content}] + history

if os.environ.get("ATTACH_LOCAL_ONCE") == "true" and os.environ.get("LAST_LOCAL_RESULT"):
    local_blob = os.environ["LAST_LOCAL_RESULT"]
    messages.append({
        "role": "system",
        "content": "Local execution output from the user machine (use as extra context):\n" + local_blob
    })

messages.append({"role": "user", "content": os.environ["USER_INPUT"]})

payload = {
    "model": os.environ["SELECTED_MODEL"],
    "messages": messages,
    "temperature": float(os.environ["TEMPERATURE"]),
    "max_tokens": int(os.environ["MAX_TOKENS"]),
}
print(json.dumps(payload, ensure_ascii=False))
PY

        curl -sS -X POST 'https://api.mistral.ai/v1/chat/completions' \
            -H 'Content-Type: application/json' \
            -H "Authorization: Bearer $api_key" \
            --data-binary @"$tmp_payload" > "$tmp_response" &
        local curl_pid=$!
        _ai_spinner "$curl_pid"
        if ! wait "$curl_pid"; then
            rm -f "$tmp_payload" "$tmp_response"
            echo -e "${C_ERR}Network error: failed to contact Mistral API.${R}"
            continue
        fi

        local ai_out
        USER_INPUT="$user_input" \
        HISTORY_FILE="$history_file" \
        RESPONSE_FILE="$tmp_response" \
        IS_CODE_MODE="$is_code_mode" \
        CODE_FILE="$code_file" \
        MAX_HISTORY="$max_history" \
        ai_out=$(python - <<'PY'
import json, os, re, sys
response_file = os.path.expanduser(os.environ["RESPONSE_FILE"])
history_file = os.path.expanduser(os.environ["HISTORY_FILE"])
code_file = os.path.expanduser(os.environ["CODE_FILE"])

with open(response_file, "r", encoding="utf-8") as f:
    raw = f.read().strip()
if not raw:
    print("Error: Empty API response")
    sys.exit(0)
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    print(f"Error: Non-JSON API response:\n{raw[:400]}")
    sys.exit(0)
if "choices" not in data:
    err = data.get("message") or data.get("error") or "Unknown API error"
    print(f"API error: {err}")
    sys.exit(0)

content = data["choices"][0]["message"]["content"].strip()
display_content = content

if os.environ["IS_CODE_MODE"] == "true":
    py_blocks = re.findall(r"```python\n(.*?)\n```", content, re.DOTALL)
    display_content = re.sub(r"```python\n(.*?)\n```", "[Python Code Hidden]", content, flags=re.DOTALL)
    if py_blocks:
        with open(code_file, "w", encoding="utf-8") as f:
            f.write("\n\n".join(py_blocks))

display_content = re.sub(r"^#+\s+", "", display_content, flags=re.MULTILINE)
print(re.sub(r"\*\*(.*?)\*\*", "\\033[1m\\1\\033[0m", display_content))

with open(history_file, "r", encoding="utf-8") as f:
    history = json.load(f)
history.append({"role": "user", "content": os.environ["USER_INPUT"]})
history.append({"role": "assistant", "content": content})
max_history = int(os.environ.get("MAX_HISTORY", "20"))
with open(history_file, "w", encoding="utf-8") as f:
    json.dump(history[-max_history:], f, ensure_ascii=False)
PY
)

        rm -f "$tmp_payload" "$tmp_response"
        attach_local_once=false

        if [[ "$show_timestamps" == true ]]; then
            echo -e "${C_OK}assistant${R} ${B}>${R} [$(date +'%H:%M:%S')]\n$ai_out\n"
        else
            echo -e "${C_OK}assistant${R} ${B}>${R}\n$ai_out\n"
        fi

        if [[ "$is_code_mode" == "true" && -f "$code_file" ]]; then
            if [[ "$direct_exec" == true ]]; then
                python "$code_file"
                rm -f "$code_file"
            else
                echo -ne "${B}Execute generated Python? (y=run/n=skip/e=edit): ${R}"
                read -r exec_choice
                case "$exec_choice" in
                    y|Y) python "$code_file" ;;
                    e|E) "${EDITOR:-vi}" "$code_file" ;;
                esac
                rm -f "$code_file"
            fi
        fi
    done
}
