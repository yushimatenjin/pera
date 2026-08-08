#!/usr/bin/env bash
# pera.sh - Ollama モデル起動 + pera メニュー (macOS / Linux)
#
# 使い方:
#   source ./pera.sh     ... 関数を読み込む
#   pera                  ... モデルと起動方法を選択して実行
#   pera -list            ... モデル一覧を表示
#   pera -launch <model>  ... 直接 launch で起動
#   pera -run <model>     ... 直接 run で起動
#   pera mcp              ... MCP サーバー管理（export / sync / install）

# MCP 設定ファイルの場所（リポジトリルートの mcp.json）
PERA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_CONFIG_PATH="$PERA_DIR/mcp.json"

# ---- Ollama モデル定義 ----
declare -A OLLAMA_MODELS=(
    ['glm-5.2']='glm-5.2:cloud'
    ['glm-5.1']='glm-5.1:cloud'
    ['deepseek-v4-flash']='deepseek-v4-flash:0731-cloud'
    ['deepseek-v4-pro']='deepseek-v4-pro:cloud'
    ['qwen3.5']='qwen3.5:397b-cloud'
    ['kimi-k3']='kimi-k3:cloud'
    ['kimi-k2.7-code']='kimi-k2.7-code:cloud'
    ['kimi-k2.6']='kimi-k2.6:cloud'
    ['nemotron-3-ultra']='nemotron-3-ultra:cloud'
    ['nemotron-3-super']='nemotron-3-super:cloud'
    ['nemotron-3-nano']='nemotron-3-nano:cloud'
    ['minimax-m3']='minimax-m3:cloud'
    ['minimax-m2.7']='minimax-m2.7:cloud'
    ['gemma4']='gemma4:cloud'
    ['mistral-large-3']='mistral-large-3:cloud'
    ['gpt-oss']='gpt-oss:cloud'
)

get_ollama_model_tag() {
    local name="$1"
    if [[ -n "${OLLAMA_MODELS[$name]:-}" ]]; then
        echo "${OLLAMA_MODELS[$name]}"
        return 0
    fi
    echo "不明なモデル: '$name'。一覧は list-models を実行してください。" >&2
    return 1
}

list-models() {
    for model_name in $(printf '%s\n' "${!OLLAMA_MODELS[@]}" | sort); do
        printf '%-20s %s\n' "$model_name" "${OLLAMA_MODELS[$model_name]}"
    done
}

# ---- MCP サーバー管理 ----
get_mcp_servers() {
    if [[ ! -f "$MCP_CONFIG_PATH" ]]; then
        echo "MCP 設定ファイルが見つかりません: $MCP_CONFIG_PATH" >&2
        return 1
    fi
    cat "$MCP_CONFIG_PATH"
}

get_tool_mcp_path() {
    local tool="$1"
    case "$tool" in
        claude)   echo "$HOME/.claude.json" ;;
        codex)    echo "$HOME/.codex/config.toml" ;;
        opencode) echo "$HOME/.config/opencode/opencode.json" ;;
        vscode)   echo "$(pwd)/.vscode/mcp.json" ;;
        cursor)   echo "$HOME/.cursor/mcp.json" ;;
        *) echo "不明なツール: $tool" >&2; return 1 ;;
    esac
}

# JSON からサーバー定義を抽出して mcp.json にマージ（jq 使用）
export_mcp_config() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq が必要です。brew install jq でインストールしてください。" >&2
        return 1
    fi
    local merged="{}"
    local tool path
    for tool in claude codex opencode vscode cursor; do
        path="$(get_tool_mcp_path "$tool")"
        [[ -f "$path" ]] || continue
        case "$tool" in
            claude|vscode|cursor)
                merged=$(jq -s '.[0] * .[1]' <(echo "$merged") <(jq '.mcpServers // {}' "$path"))
                ;;
            opencode)
                merged=$(jq -s '.[0] * .[1]' <(echo "$merged") <(jq '.mcp // {}' "$path"))
                ;;
            codex)
                # TOML は jq で直接読めないため、簡易パース
                local name cmd args
                while IFS= read -r line; do
                    if [[ "$line" =~ ^\[mcp_servers\.([^\]]+)\] ]]; then
                        name="${BASH_REMATCH[1]}"
                        [[ "$name" == *.env ]] && continue
                        cmd=""
                        args="[]"
                    elif [[ -n "$name" && "$line" =~ ^command[[:space:]]*=[[:space:]]*\'(.+)\' ]]; then
                        cmd="${BASH_REMATCH[1]}"
                    elif [[ -n "$name" && "$line" =~ ^args[[:space:]]*=[[:space:]]*\[(.*)\] ]]; then
                        args="[$(echo "${BASH_REMATCH[1]}" | sed "s/'/\"/g")]"
                    elif [[ -n "$name" && -z "$cmd" && -z "$args" ]]; then
                        :
                    fi
                    if [[ -n "$name" && -n "$cmd" ]]; then
                        merged=$(jq --arg n "$name" --arg c "$cmd" --argjson a "$args" \
                            '.[$n] = {command: $c, args: $a, env: {}}' <<<"$merged")
                        name=""
                    fi
                done < "$path"
                ;;
        esac
    done
    jq '{servers: .}' <<<"$merged" > "$MCP_CONFIG_PATH"
    echo "MCP 設定を $MCP_CONFIG_PATH に書き出しました。"
}

# mcp.json のサーバーを指定ツールに配布
install_mcp_to_tool() {
    local tool="$1"
    local path servers
    path="$(get_tool_mcp_path "$tool")" || return 1
    servers="$(get_mcp_servers)" || return 1
    case "$tool" in
        claude|vscode|cursor)
            local dir
            dir="$(dirname "$path")"
            [[ -d "$dir" ]] || mkdir -p "$dir"
            if [[ -f "$path" ]]; then
                jq --argjson s "$(jq '.servers' <<<"$servers")" \
                    '.mcpServers = ((.mcpServers // {}) + $s)' "$path" > "$path.tmp" && mv "$path.tmp" "$path"
            else
                jq --argjson s "$(jq '.servers' <<<"$servers")" \
                    '{mcpServers: $s}' <<<"{}" > "$path"
            fi
            ;;
        opencode)
            if [[ -f "$path" ]]; then
                jq --argjson s "$(jq '.servers' <<<"$servers")" \
                    '.mcp = ((.mcp // {}) + $s)' "$path" > "$path.tmp" && mv "$path.tmp" "$path"
            else
                jq --argjson s "$(jq '.servers' <<<"$servers")" \
                    '{mcp: $s}' <<<"{}" > "$path"
            fi
            ;;
        codex)
            # TOML 追記
            {
                [[ -f "$path" ]] && cat "$path"
                echo ""
                jq -r '.servers | to_entries[] | 
                    "[mcp_servers." + .key + "]\ncommand = \x27" + .value.command + "\x27\nargs = [" + 
                    (.value.args | map("\x27" + . + "\x27") | join(", ")) + "]\nenabled = true\n"' <<<"$servers"
            } > "$path.tmp" && mv "$path.tmp" "$path"
            ;;
    esac
    echo "$tool に MCP を書き込みました: $path"
}

pera_mcp() {
    local action="$1" tool="$2"
    if [[ -z "$action" ]]; then
        echo "MCP 管理メニュー:"
        echo "  1) export   ... 各ツールの MCP 設定を吸い出して mcp.json に集約"
        echo "  2) sync     ... mcp.json を全ツールに配布"
        echo "  3) install  ... mcp.json を指定ツールに配布"
        read -rp "番号を入力 (0 でキャンセル): " choice
        case "$choice" in
            1) action="export" ;;
            2) action="sync" ;;
            3) action="install" ;;
            *) return ;;
        esac
    fi
    case "$action" in
        export) export_mcp_config ;;
        sync)
            for t in claude codex opencode vscode cursor; do
                install_mcp_to_tool "$t"
            done
            ;;
        install)
            if [[ -z "$tool" ]]; then
                echo "MCP サーバーをインストールするツールを選択してください:"
                echo "  1) claude  2) codex  3) opencode  4) vscode  5) cursor  6) すべて"
                read -rp "番号を入力 (0 でキャンセル): " choice
                case "$choice" in
                    1) tool="claude" ;;
                    2) tool="codex" ;;
                    3) tool="opencode" ;;
                    4) tool="vscode" ;;
                    5) tool="cursor" ;;
                    6) tool="all" ;;
                    *) return ;;
                esac
            fi
            if [[ "$tool" == "all" ]]; then
                for t in claude codex opencode vscode cursor; do
                    install_mcp_to_tool "$t"
                done
            else
                install_mcp_to_tool "$tool"
            fi
            ;;
        *) echo "不明なアクション: $action (export / sync / install)" >&2 ;;
    esac
}

# ---- pera: モデル起動の選択式メニュー ----
pera() {
    local model="" list=0 launch=0 run=0
    local choice idx claude_idx codex_idx danger yolo

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -list) list=1 ;;
            -launch) launch=1; shift; model="$1" ;;
            -run) run=1; shift; model="$1" ;;
            mcp) pera_mcp "$2" "$3"; return ;;
            *) model="$1" ;;
        esac
        shift
    done

    if [[ $list -eq 1 ]]; then
        list-models
        return
    fi

    # モデル未指定なら選択式で選ぶ
    if [[ -z "$model" ]]; then
        local names=()
        while IFS= read -r n; do names+=("$n"); done < <(printf '%s\n' "${!OLLAMA_MODELS[@]}" | sort)

        echo "モデルを選択してください:"
        local i=0
        for n in "${names[@]}"; do
            i=$((i + 1))
            printf '%2d) %-20s %s\n' "$i" "$n" "${OLLAMA_MODELS[$n]}"
        done
        claude_idx=$((i + 1))
        codex_idx=$((i + 2))
        printf '%2d) %s\n' "$claude_idx" "claude"
        printf '%2d) %s\n' "$codex_idx" "codex"

        read -rp "番号を入力 (0 でキャンセル): " choice
        if [[ "$choice" == "0" || -z "$choice" ]]; then return; fi

        if [[ "$choice" == "$claude_idx" ]]; then
            read -rp "claude を dangerous モードで起動しますか? (y/N): " danger
            if [[ "$danger" =~ ^[yY] ]]; then claude --dangerously-skip-permissions
            else claude; fi
            return
        fi
        if [[ "$choice" == "$codex_idx" ]]; then
            read -rp "codex を yolo モードで起動しますか? (y/N): " yolo
            if [[ "$yolo" =~ ^[yY] ]]; then codex --dangerously-bypass-approvals-and-sandbox
            else codex; fi
            return
        fi

        idx=$((choice - 1))
        if (( idx < 0 || idx >= ${#names[@]} )); then
            echo "無効な番号です。" >&2
            return
        fi
        model="${names[$idx]}"
    fi

    local tag
    tag="$(get_ollama_model_tag "$model")" || return

    # 起動方法が未指定なら選択式で選ぶ
    if [[ $launch -eq 0 && $run -eq 0 ]]; then
        echo "起動方法を選択してください ($model):"
        echo "  1) opencode ... ollama launch opencode で起動"
        echo "  2) claude   ... claude で起動"
        echo "  3) codex    ... codex で起動"
        echo "  4) vscode   ... VS Code で開く"
        echo "  5) cursor   ... Cursor で開く"
        echo "  6) run      ... ollama run で起動（初回取得用）"
        read -rp "番号を入力 (0 でキャンセル): " choice
        if [[ "$choice" == "0" || -z "$choice" ]]; then return; fi
        case "$choice" in
            1) launch=1 ;;
            2)
                read -rp "claude を dangerous モードで起動しますか? (y/N): " danger
                if [[ "$danger" =~ ^[yY] ]]; then claude --dangerously-skip-permissions
                else claude; fi
                return
                ;;
            3)
                read -rp "codex を yolo モードで起動しますか? (y/N): " yolo
                if [[ "$yolo" =~ ^[yY] ]]; then codex --dangerously-bypass-approvals-and-sandbox
                else codex; fi
                return
                ;;
            4) open_editor vscode; return ;;
            5) open_editor cursor; return ;;
            6) run=1 ;;
            *) echo "無効な番号です。" >&2; return ;;
        esac
    fi

    if [[ $launch -eq 1 ]]; then
        ollama launch opencode --model "$tag"
    elif [[ $run -eq 1 ]]; then
        ollama run "$tag"
    fi
}

open_editor() {
    local editor="$1"
    local cwd
    cwd="$(pwd)"
    case "$editor" in
        vscode)
            if command -v code >/dev/null 2>&1; then code "$cwd"
            elif [[ "$(uname)" == "Darwin" ]]; then open -a "Visual Studio Code" "$cwd"
            else code "$cwd"; fi
            ;;
        cursor)
            if command -v cursor >/dev/null 2>&1; then cursor "$cwd"
            elif [[ "$(uname)" == "Darwin" ]]; then open -a "Cursor" "$cwd"
            else cursor "$cwd"; fi
            ;;
    esac
}
