ai() {
    local key_file="$HOME/.mistral_key"
    local api_key=""

    # 1. Check if the key is stored in a file
    if [ -f "$key_file" ]; then
        api_key=$(cat "$key_file")
    fi

    # 2. If there's no key, ask for it
    if [ -z "$api_key" ]; then
        echo -e "\033[33m[!] No API key found.\033[0m"
        echo -n "Please enter your Mistral API key: "
        read -r input_key  # Removed the 's' flag to make input visible
        echo "" # New line after input

        if [ -z "$input_key" ]; then
            echo "Error: No key entered."
            return 1
        fi

        # Basic key validation (e.g., length)
        if [ ${#input_key} -lt 32 ]; then
            echo "Error: The entered key does not appear to be valid (too short)."
            return 1
        fi

        # Save the key to the file
        echo "$input_key" > "$key_file"
        chmod 600 "$key_file"  # Set permissions for security
        api_key="$input_key"
    fi
    local selected_model="mistral-tiny"
    local is_code_mode=false
    local direct_exec=false
    local B='\033[1m'; local R='\033[0m'

    # Vlaggen verwerken
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -m|--model) selected_model="$2"; shift 2 ;;
            -c|--code) selected_model="codestral-latest"; is_code_mode=true; shift 1 ;;
            -d|--directly) direct_exec=true; shift 1 ;;
            *) break ;;
        esac
    done

    # --- GESCHIEDENIS RESET BIJ START ---
    local history_file="$HOME/.ai_history.json"
    echo "[]" > "$history_file"
    # ------------------------------------

    # Logs
    local logs=("\033[38;2;255;0;0m[!!] CRITICAL ERROR:\033[0m USER TOO AWESOME FOR STANDARD CHAT." "[!!] ATTEMPTING WORKAROUND... [OK]" "\033[38;2;255;0;0m[!!] WARNING: THIS TERMINAL MAY CONTAIN TRACES OF PUNNY JOKES.\033[0m" "[!!] LOADING... 99% (STUCK HERE FOR DRAMATIC EFFECT)" "[\033[32m▰\033[0m▱▱▱▱▱▱▱▱▱] 10% (Finding the right words...)" "[\033[32m▰▰▰\033[0m▱▱▱▱▱▱▱] 30% (Compiling your thoughts...)" "[\033[32m▰▰▰▰▰▰\033[0m▱▱▱▱] 60% (Debugging typos...)" "[\033[32m▰▰▰▰▰▰▰▰▰\033[0m▱] 90% (Almost there!)" "[\033[32m▰▰▰▰▰▰▰▰▰▰\033[0m] 100% (Ready to chat!)" "\033[38;2;255;0;0m[!!] JUST KIDDING! WELCOME.\033[0m")
    for log in "${logs[@]}"; do echo -e "[$(date +'%H:%M:%S')] ${log}"; sleep 2; done

echo -e " .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------. 
| .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
| | ____    ____ | || |     _____    | || |    _______   | || |  _________   | || |  _______     | || |      __      | || |   _____      | |
| ||_   \  /   _|| || |    |_   _|   | || |   /  ___  |  | || | |  _   _  |  | || | |_   __ \    | || |     /  \     | || |  |_   _|     | |
| |  |   \/   |  | || |      | |     | || |  |  (__ \_|  | || | |_/ | | \_|  | || |   | |__) |   | || |    / /\ \    | || |    | |       | |
| |  | |\  /| |  | || |      | |     | || |   '.___'-.   | || |     | |      | || |   |  __ /    | || |   / ____ \   | || |    | |   _   | |
| | _| |_\/_| |_ | || |     _| |_    | || |  |'\____) |  | || |    _| |_     | || |  _| |  \ \_  | || | _/ /    \ \_ | || |   _| |__/ |  | |
| ||_____||_____|| || |    |_____|   | || |  |_______.'  | || |   |_____|    | || | |____| |___| | || ||____|  |____|| || |  |________|  | |
| |              | || |              | || |              | || |              | || |              | || |              | || |              | |
| '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------' " | \
awk '{
    for (i=1; i<=length($0); i++) {
        char = substr($0, i, 1);
        # Creëert een vloeiende overgang door de 256-kleuren tabel
        # Gebruikt een offset (38;5) voor de voorgrondkleur
        color = 16 + (i + NR) % 214; 
        if (char == " ") {
            printf " ";
        } else {
            printf "\033[38;5;%dm%s\033[0m", color, char;
        }
    }
    printf "\n";
}'

    while true; do
        echo -ne ">>> "
        read -r user_input
        if [[ "$user_input" == "exit" || "$user_input" == "quit" ]]; then break; fi
        if [ -z "$user_input" ]; then continue; fi

        local json_data=$(python -u -c "
import json, os, sys, codecs
sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer)
h_file = os.path.expanduser('~/.ai_history.json')
with open(h_file, 'r', encoding='utf-8') as f:
    h = json.load(f)

if '$is_code_mode' == 'true':
    system_content = 'You are a coding expert. If using matplotlib: 1. Use matplotlib.use(\"Agg\") 2. Use plt.savefig(\"plot.png\").'
else:
    system_content = 'Je bent een gezellige chatbuddy. Antwoord in de taal van de gebruiker. Geef GEEN codeblokken tenzij er specifiek om gevraagd wordt.'

messages = [{'role': 'system', 'content': system_content}] + h + [{'role': 'user', 'content': r'''$user_input'''}]
print(json.dumps({'model': '$selected_model', 'messages': messages}, ensure_ascii=False))
")

        local response=$(curl -s -X POST 'https://api.mistral.ai/v1/chat/completions' \
             --ssl-no-revoke \
             -H 'Content-Type: application/json' \
             -H "Authorization: Bearer $api_key" \
             -d "$json_data")

        local ai_out=$(echo "$response" | python -u -c "
import sys, json, re, os, codecs
sys.stdin = codecs.getreader('utf-8')(sys.stdin.buffer)
sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer)

try:
    data = json.loads(sys.stdin.read())
    if 'choices' in data:
        content = data['choices'][0]['message']['content'].strip()
        
        py_blocks = []
        display_content = content
        if '$is_code_mode' == 'true':
            py_blocks = re.findall(r'\`{3}python\n(.*?)\n\`{3}', content, re.DOTALL)
            display_content = re.sub(r'\`{3}python\n(.*?)\n\`{3}', '[Python Code Hidden]', content, flags=re.DOTALL)
        
        display_content = re.sub(r'^#+\s+', '', display_content, flags=re.MULTILINE)
        C_B = '\033[1m'; C_R = '\033[0m'
        print(re.sub(r'\*\*(.*?)\*\*', f'{C_B}\\\\1{C_R}', display_content))
        
        if py_blocks and '$is_code_mode' == 'true':
            with open(os.path.expanduser('~/.ai_code.py'), 'w', encoding='utf-8') as f:
                full_code = '\n\n'.join(py_blocks)
                if 'matplotlib' in full_code:
                    f.write('import matplotlib\nmatplotlib.use(\"Agg\")\nimport matplotlib.pyplot as plt\n\n')
                f.write(full_code)
                if 'matplotlib' in full_code and 'savefig' not in full_code:
                    f.write('\nplt.savefig(\"plot.png\")\n')
        
        h_file = os.path.expanduser('~/.ai_history.json')
        with open(h_file, 'r', encoding='utf-8') as f: h = json.load(f)
        h.append({'role': 'user', 'content': r'''$user_input'''})
        h.append({'role': 'assistant', 'content': content})
        with open(h_file, 'w', encoding='utf-8') as f: json.dump(h[-20:], f, ensure_ascii=False)
    else:
        print('Fout: ' + data.get('message', 'Onbekende API fout'))
except Exception as e:
    print('Error: ' + str(e))
")
        echo -e "\n$ai_out\n"

        if [[ "$is_code_mode" == "true" && -f "$HOME/.ai_code.py" ]]; then
            if [ "$direct_exec" = true ]; then
                python -u "$HOME/.ai_code.py"; [ -f "plot.png" ] && start plot.png; rm "$HOME/.ai_code.py"
            else
                echo -ne "${B}Execute code? (y/n/s): ${R}"
                read -r exec_choice
                case "$exec_choice" in
                    y|Y) python -u "$HOME/.ai_code.py"; [ -f "plot.png" ] && start plot.png; rm "$HOME/.ai_code.py" ;;
                    s|S) notepad.exe "$(cygpath -w "$HOME/.ai_code.py")"; rm "$HOME/.ai_code.py" ;;
                    *) rm "$HOME/.ai_code.py" ;;
                esac
            fi
        fi
    done
}
