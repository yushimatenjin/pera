# pera.ps1 - Ollama モデル起動 + pera メニュー
#
# 使い方:
#   . ./pera.ps1          ... 関数を読み込む
#   pera                  ... モデルと起動方法を選択して実行
#   pera -list            ... モデル一覧を表示
#   pera -launch <model>  ... 直接 launch で起動
#   pera -run <model>     ... 直接 run で起動
#   launch-<model>        ... モデルごとの launch ショートカット
#   run-<model>           ... モデルごとの run ショートカット

# ---- Ollama モデル定義 ----
$script:OllamaModels = @{
    'glm-5.2'            = 'glm-5.2:cloud'
    'glm-5.1'            = 'glm-5.1:cloud'
    'deepseek-v4-flash'  = 'deepseek-v4-flash:0731-cloud'
    'deepseek-v4-pro'    = 'deepseek-v4-pro:cloud'
    'qwen3.5'            = 'qwen3.5:397b-cloud'
    'kimi-k3'            = 'kimi-k3:cloud'
    'kimi-k2.7-code'     = 'kimi-k2.7-code:cloud'
    'kimi-k2.6'          = 'kimi-k2.6:cloud'
    'nemotron-3-ultra'   = 'nemotron-3-ultra:cloud'
    'nemotron-3-super'   = 'nemotron-3-super:cloud'
    'nemotron-3-nano'    = 'nemotron-3-nano:cloud'
    'minimax-m3'         = 'minimax-m3:cloud'
    'minimax-m2.7'       = 'minimax-m2.7:cloud'
    'gemma4'             = 'gemma4:cloud'
    'mistral-large-3'    = 'mistral-large-3:cloud'
    'gpt-oss'            = 'gpt-oss:cloud'
}

function Get-OllamaModelTag {
    param([string]$Name)
    if ($script:OllamaModels.ContainsKey($Name)) {
        return $script:OllamaModels[$Name]
    }
    Write-Error "不明なモデル: '$Name'。一覧は list-models を実行してください。"
    return $null
}

# モデルごとに launch-<model> / run-<model> 関数を生成
foreach ($modelName in $script:OllamaModels.Keys) {
    $tag = $script:OllamaModels[$modelName]
    $launchBody = "ollama launch opencode --model $tag"
    $runBody = "ollama run $tag"
    New-Item -Path "function:launch-$modelName" -Value ([scriptblock]::Create($launchBody)) -Force | Out-Null
    New-Item -Path "function:run-$modelName" -Value ([scriptblock]::Create($runBody)) -Force | Out-Null
}

function list-models {
    $script:OllamaModels.Keys | Sort-Object | ForEach-Object {
        "{0,-20} {1}" -f $_, $script:OllamaModels[$_]
    }
}

# ---- pera: モデル起動の選択式メニュー ----
function pera {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Model,
        [switch]$List,
        [switch]$Launch,
        [switch]$Run
    )

    if ($List) {
        list-models
        return
    }

    # モデル未指定なら選択式で選ぶ
    if (-not $Model) {
        $names = $script:OllamaModels.Keys | Sort-Object
        Write-Host "モデルを選択してください:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $names.Count; $i++) {
            "{0,2}) {1,-20} {2}" -f ($i + 1), $names[$i], $script:OllamaModels[$names[$i]]
        }
        $claudeIdx = $names.Count + 1
        $codexIdx = $names.Count + 2
        "{0,2}) {1}" -f $claudeIdx, "claude"
        "{0,2}) {1}" -f $codexIdx, "codex"
        $choice = Read-Host "番号を入力 (0 でキャンセル)"
        if ($choice -eq '0' -or [string]::IsNullOrWhiteSpace($choice)) { return }
        if ($choice -eq $claudeIdx) {
            $danger = Read-Host "claude を dangerous モードで起動しますか? (y/N)"
            if ($danger -match '^[yY]') { claude --dangerously-skip-permissions }
            else { claude }
            return
        }
        if ($choice -eq $codexIdx) {
            $yolo = Read-Host "codex を yolo モードで起動しますか? (y/N)"
            if ($yolo -match '^[yY]') { codex --dangerously-bypass-approvals-and-sandbox }
            else { codex }
            return
        }
        $idx = [int]$choice - 1
        if ($idx -lt 0 -or $idx -ge $names.Count) {
            Write-Error "無効な番号です。"
            return
        }
        $Model = $names[$idx]
    }

    $tag = Get-OllamaModelTag $Model
    if (-not $tag) { return }

    # 起動方法が未指定なら選択式で選ぶ
    if (-not ($Launch -or $Run)) {
        Write-Host "起動方法を選択してください ($Model):" -ForegroundColor Cyan
        Write-Host "  1) opencode ... ollama launch opencode で起動"
        Write-Host "  2) claude   ... claude --dangerously-skip-permissions で起動"
        Write-Host "  3) codex    ... codex で起動"
        Write-Host "  4) run      ... ollama run で起動（初回取得用）"
        $choice = Read-Host "番号を入力 (0 でキャンセル)"
        if ($choice -eq '0' -or [string]::IsNullOrWhiteSpace($choice)) { return }
        if ($choice -eq '1') { $Launch = $true }
        elseif ($choice -eq '2') {
            $danger = Read-Host "claude を dangerous モードで起動しますか? (y/N)"
            if ($danger -match '^[yY]') { claude --dangerously-skip-permissions }
            else { claude }
            return
        }
        elseif ($choice -eq '3') {
            $yolo = Read-Host "codex を yolo モードで起動しますか? (y/N)"
            if ($yolo -match '^[yY]') { codex --dangerously-bypass-approvals-and-sandbox }
            else { codex }
            return
        }
        elseif ($choice -eq '4') { $Run = $true }
        else {
            Write-Error "無効な番号です。"
            return
        }
    }

    if ($Launch) { ollama launch opencode --model $tag }
    elseif ($Run) { ollama run $tag }
}
