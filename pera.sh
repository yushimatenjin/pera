#!/usr/bin/env bash
# pera.sh - Ollama モデル起動 + pera メニュー (macOS / Linux)
#
# 使い方:
#   source ./pera.sh     ... 関数を読み込む
#   pera                  ... モデルと起動方法を選択して実行
#   pera -list            ... モデル一覧を表示
#   pera -launch <model>  ... 直接 launch で起動
#   pera -run <model>     ... 直接 run で起動

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

# ---- pera: モデル起動の選択式メニュー ----
pera() {
    local model="" list=0 launch=0 run=0
    local choice idx claude_idx codex_idx danger yolo

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -list) list=1 ;;
            -launch) launch=1; shift; model="$1" ;;
            -run) run=1; shift; model="$1" ;;
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
        echo "  2) claude   ... claude --dangerously-skip-permissions で起動"
        echo "  3) codex    ... codex で起動"
        echo "  4) run      ... ollama run で起動（初回取得用）"
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
            4) run=1 ;;
            *) echo "無効な番号です。" >&2; return ;;
        esac
    fi

    if [[ $launch -eq 1 ]]; then
        ollama launch opencode --model "$tag"
    elif [[ $run -eq 1 ]]; then
        ollama run "$tag"
    fi
}
