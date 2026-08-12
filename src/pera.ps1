# pera.ps1 - Ollama モデル起動 + pera メニュー
#
# 使い方:
#   . ./pera.ps1          ... 関数を読み込む
#   pera                  ... モデルと起動方法を選択して実行
#   pera -list            ... モデル一覧を表示
#   pera -launch <model>  ... 直接 launch で起動
#   pera -run <model>     ... 直接 run で起動
#   pera -mcp             ... MCP サーバーを各ツールにインストール

# MCP 設定ファイルの場所（リポジトリルートの mcp.json）
$script:PeraDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:McpConfigPath = Join-Path (Split-Path -Parent $script:PeraDir) "mcp.json"

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

function list-models {
    $script:OllamaModels.Keys | Sort-Object | ForEach-Object {
        "{0,-20} {1}" -f $_, $script:OllamaModels[$_]
    }
}

# ---- MCP サーバー管理 ----
function Get-McpServers {
    if (-not (Test-Path $script:McpConfigPath)) {
        Write-Error "MCP 設定ファイルが見つかりません: $script:McpConfigPath"
        return $null
    }
    $config = Get-Content $script:McpConfigPath -Raw | ConvertFrom-Json
    return $config.servers
}

function Get-ToolMcpPath {
    param([string]$Tool)
    switch ($Tool) {
        'claude'   { return (Join-Path $HOME ".claude.json") }
        'codex'    { return (Join-Path $HOME ".codex\config.toml") }
        'opencode' { return (Join-Path $HOME ".config\opencode\opencode.json") }
        'vscode'   { return (Join-Path (Get-Location) ".vscode\mcp.json") }
        'cursor'   { return (Join-Path $HOME ".cursor\mcp.json") }
        default    { Write-Error "不明なツール: $Tool"; return $null }
    }
}

# ---- MCP 設定の吸い出し（export） ----
function Read-McpFromClaude {
    $path = Get-ToolMcpPath 'claude'
    if (-not (Test-Path $path)) { return @{} }
    $json = Get-Content $path -Raw | ConvertFrom-Json
    $result = @{}
    if ($json.mcpServers) {
        foreach ($name in $json.mcpServers.PSObject.Properties.Name) {
            $s = $json.mcpServers.$name
            $result[$name] = @{
                command = $s.command
                args    = @($s.args)
                env     = $s.env
            }
        }
    }
    return $result
}

function Read-McpFromCodex {
    $path = Get-ToolMcpPath 'codex'
    if (-not (Test-Path $path)) { return @{} }
    $lines = Get-Content $path
    $result = @{}
    $current = $null
    $currentEnv = $null
    foreach ($line in $lines) {
        if ($line -match '^\s*\[mcp_servers\.([^\]]+)\]') {
            $name = $Matches[1]
            if ($name -match '\.env$') {
                $currentEnv = $name -replace '\.env$', ''
                $current = $null
            }
            else {
                $current = $name
                $currentEnv = $null
                if (-not $result.ContainsKey($name)) {
                    $result[$name] = @{ command = ''; args = @(); env = @{} }
                }
            }
        }
        elseif ($current -and $line -match '^\s*command\s*=\s*''(.+)''') {
            $result[$current].command = $Matches[1]
        }
        elseif ($current -and $line -match '^\s*args\s*=\s*\[(.*)\]') {
            $argsStr = $Matches[1]
            $result[$current].args = @($argsStr -split ',' | ForEach-Object { $_.Trim().Trim("'") })
        }
        elseif ($currentEnv -and $line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"(.+)"') {
            $result[$currentEnv].env[$Matches[1]] = $Matches[2]
        }
    }
    return $result
}

function Read-McpFromOpenCode {
    $path = Get-ToolMcpPath 'opencode'
    if (-not (Test-Path $path)) { return @{} }
    $json = Get-Content $path -Raw | ConvertFrom-Json
    $result = @{}
    if ($json.mcp) {
        foreach ($name in $json.mcp.PSObject.Properties.Name) {
            $s = $json.mcp.$name
            $cmd = $s.command
            $args = @()
            if ($s.args) { $args = @($s.args) }
            if ($cmd -is [array]) {
                $args = @($cmd[1..($cmd.Count - 1)]) + $args
                $cmd = $cmd[0]
            }
            $result[$name] = @{
                command = $cmd
                args    = $args
                env     = if ($s.environment) { $s.environment } else { @{} }
            }
        }
    }
    return $result
}

function Read-McpFromVSCode {
    $path = Get-ToolMcpPath 'vscode'
    if (-not (Test-Path $path)) { return @{} }
    $json = Get-Content $path -Raw | ConvertFrom-Json
    $result = @{}
    if ($json.mcpServers) {
        foreach ($name in $json.mcpServers.PSObject.Properties.Name) {
            $s = $json.mcpServers.$name
            $result[$name] = @{
                command = $s.command
                args    = @($s.args)
                env     = $s.env
            }
        }
    }
    return $result
}

function Read-McpFromCursor {
    $path = Get-ToolMcpPath 'cursor'
    if (-not (Test-Path $path)) { return @{} }
    $json = Get-Content $path -Raw | ConvertFrom-Json
    $result = @{}
    if ($json.mcpServers) {
        foreach ($name in $json.mcpServers.PSObject.Properties.Name) {
            $s = $json.mcpServers.$name
            $result[$name] = @{
                command = $s.command
                args    = @($s.args)
                env     = if ($s.env) { $s.env } else { @{} }
            }
        }
    }
    return $result
}

function Export-McpConfig {
    $tools = @('claude', 'codex', 'opencode', 'vscode', 'cursor')
    $merged = @{}
    $conflicts = @()
    foreach ($tool in $tools) {
        $servers = switch ($tool) {
            'claude'   { Read-McpFromClaude }
            'codex'    { Read-McpFromCodex }
            'opencode' { Read-McpFromOpenCode }
            'vscode'   { Read-McpFromVSCode }
            'cursor'   { Read-McpFromCursor }
        }
        foreach ($name in $servers.Keys) {
            if ($merged.ContainsKey($name)) {
                $conflicts += @{ Name = $name; Tool = $tool }
            }
            else {
                $merged[$name] = $servers[$name]
            }
        }
    }
    if ($conflicts.Count -gt 0) {
        Write-Host "同名の MCP サーバーが複数ツールにあります:" -ForegroundColor Yellow
        foreach ($c in $conflicts) {
            Write-Host "  $($c.Name) (既存: $($c.Tool))"
        }
        $choice = Read-Host "既存の定義を保持しますか? (y/N)"
        if ($choice -notmatch '^[yY]') {
            Write-Host "export を中止しました。"
            return
        }
    }
    $config = @{ servers = $merged }
    $config | ConvertTo-Json -Depth 10 | Set-Content $script:McpConfigPath -Encoding UTF8
    Write-Host "MCP 設定を $script:McpConfigPath に書き出しました。" -ForegroundColor Green
}

function Install-McpToClaude {
    param($Servers)
    $path = Get-ToolMcpPath 'claude'
    $json = @{}
    if (Test-Path $path) {
        $json = Get-Content $path -Raw | ConvertFrom-Json
    }
    if (-not $json.mcpServers) { $json.mcpServers = @{} }
    foreach ($name in $Servers.PSObject.Properties.Name) {
        $s = $Servers.$name
        $entry = @{
            type    = 'stdio'
            command = $s.command
            args    = @($s.args)
            env     = $s.env
        }
        if ($json.mcpServers -is [System.Collections.IDictionary]) {
            $json.mcpServers[$name] = $entry
        }
        else {
            $json.mcpServers | Add-Member -NotePropertyName $name -NotePropertyValue $entry -Force
        }
    }
    $json | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
    Write-Host "claude に MCP を書き込みました: $path" -ForegroundColor Green
}

function Install-McpToCodex {
    param($Servers)
    $path = Get-ToolMcpPath 'codex'
    $lines = @()
    if (Test-Path $path) {
        $lines = Get-Content $path
    }
    $sb = [System.Text.StringBuilder]::new()
    $inMcpSection = $false
    $currentServer = $null
    foreach ($line in $lines) {
        if ($line -match '^\s*\[mcp_servers\.([^\]]+)\]') {
            $serverName = $Matches[1] -replace '\.env$', ''
            $currentServer = $serverName
            $inMcpSection = $true
            if ($Servers.PSObject.Properties.Name -contains $serverName) {
                continue
            }
            [void]$sb.AppendLine($line)
            continue
        }
        if ($inMcpSection) {
            if ($line -match '^\s*\[') {
                $inMcpSection = $false
                $currentServer = $null
                [void]$sb.AppendLine($line)
                continue
            }
            if ($currentServer -and ($Servers.PSObject.Properties.Name -contains $currentServer)) {
                continue
            }
            [void]$sb.AppendLine($line)
            continue
        }
        [void]$sb.AppendLine($line)
    }
    foreach ($name in $Servers.PSObject.Properties.Name) {
        $s = $Servers.$name
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("[mcp_servers.$name]")
        [void]$sb.AppendLine("command = '$($s.command)'")
        $argsStr = ($s.args | ForEach-Object { "'$_'" }) -join ', '
        [void]$sb.AppendLine("args = [$argsStr]")
        [void]$sb.AppendLine("enabled = true")
        if ($s.env) {
            foreach ($envName in $s.env.PSObject.Properties.Name) {
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine("[mcp_servers.$name.env]")
                [void]$sb.AppendLine("$envName = `"$($s.env.$envName)`"")
            }
        }
    }
    $sb.ToString() | Set-Content $path -Encoding UTF8
    Write-Host "codex に MCP を書き込みました: $path" -ForegroundColor Green
}

function Install-McpToOpenCode {
    param($Servers)
    $path = Get-ToolMcpPath 'opencode'
    $json = @{}
    if (Test-Path $path) {
        $json = Get-Content $path -Raw | ConvertFrom-Json
    }
    if (-not $json.mcp) { $json.mcp = @{} }
    foreach ($name in $Servers.PSObject.Properties.Name) {
        $s = $Servers.$name
        $entry = @{
            command     = @($s.command) + @($s.args)
            enabled     = $true
            type        = 'local'
            environment = $s.env
        }
        if ($json.mcp -is [System.Collections.IDictionary]) {
            $json.mcp[$name] = $entry
        }
        else {
            $json.mcp | Add-Member -NotePropertyName $name -NotePropertyValue $entry -Force
        }
    }
    $json | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
    Write-Host "opencode に MCP を書き込みました: $path" -ForegroundColor Green
}

function Install-McpToVSCode {
    param($Servers)
    $path = Get-ToolMcpPath 'vscode'
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = @{}
    if (Test-Path $path) {
        $json = Get-Content $path -Raw | ConvertFrom-Json
    }
    if (-not $json.mcpServers) { $json.mcpServers = @{} }
    foreach ($name in $Servers.PSObject.Properties.Name) {
        $s = $Servers.$name
        $entry = @{
            command = $s.command
            args    = @($s.args)
            env     = $s.env
        }
        if ($json.mcpServers -is [System.Collections.IDictionary]) {
            $json.mcpServers[$name] = $entry
        }
        else {
            $json.mcpServers | Add-Member -NotePropertyName $name -NotePropertyValue $entry -Force
        }
    }
    $json | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
    Write-Host "vscode に MCP を書き込みました: $path" -ForegroundColor Green
}

function Install-McpToCursor {
    param($Servers)
    $path = Get-ToolMcpPath 'cursor'
    $json = @{}
    if (Test-Path $path) {
        $json = Get-Content $path -Raw | ConvertFrom-Json
    }
    if (-not $json.mcpServers) { $json.mcpServers = @{} }
    foreach ($name in $Servers.PSObject.Properties.Name) {
        $s = $Servers.$name
        $entry = @{
            command = $s.command
            args    = @($s.args)
            env     = $s.env
        }
        if ($json.mcpServers -is [System.Collections.IDictionary]) {
            $json.mcpServers[$name] = $entry
        }
        else {
            $json.mcpServers | Add-Member -NotePropertyName $name -NotePropertyValue $entry -Force
        }
    }
    $json | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
    Write-Host "cursor に MCP を書き込みました: $path" -ForegroundColor Green
}

function pera-mcp {
    param(
        [Parameter(Position = 0)]
        [string]$Action,
        [Parameter(Position = 1)]
        [string]$Tool
    )

    if (-not $Action) {
        Write-Host "MCP 管理メニュー:" -ForegroundColor Cyan
        Write-Host "  1) export   ... 各ツールの MCP 設定を吸い出して mcp.json に集約"
        Write-Host "  2) sync     ... mcp.json を全ツールに配布"
        Write-Host "  3) install  ... mcp.json を指定ツールに配布"
        $choice = Read-Host "番号を入力 (0 でキャンセル)"
        if ($choice -eq '0' -or [string]::IsNullOrWhiteSpace($choice)) { return }
        $Action = switch ($choice) {
            '1' { 'export' }
            '2' { 'sync' }
            '3' { 'install' }
            default { Write-Error "無効な番号です。"; return }
        }
    }

    switch ($Action) {
        'export' {
            Export-McpConfig
        }
        'sync' {
            $servers = Get-McpServers
            if (-not $servers) { return }
            foreach ($t in @('claude', 'codex', 'opencode', 'vscode', 'cursor')) {
                switch ($t) {
                    'claude'   { Install-McpToClaude $servers }
                    'codex'    { Install-McpToCodex $servers }
                    'opencode' { Install-McpToOpenCode $servers }
                    'vscode'   { Install-McpToVSCode $servers }
                    'cursor'   { Install-McpToCursor $servers }
                }
            }
        }
        'install' {
            if (-not $Tool) {
                Write-Host "MCP サーバーをインストールするツールを選択してください:" -ForegroundColor Cyan
                Write-Host "  1) claude"
                Write-Host "  2) codex"
                Write-Host "  3) opencode"
                Write-Host "  4) vscode"
                Write-Host "  5) cursor"
                Write-Host "  6) すべて"
                $choice = Read-Host "番号を入力 (0 でキャンセル)"
                if ($choice -eq '0' -or [string]::IsNullOrWhiteSpace($choice)) { return }
                $Tool = switch ($choice) {
                    '1' { 'claude' }
                    '2' { 'codex' }
                    '3' { 'opencode' }
                    '4' { 'vscode' }
                    '5' { 'cursor' }
                    '6' { 'all' }
                    default { Write-Error "無効な番号です。"; return }
                }
            }
            $servers = Get-McpServers
            if (-not $servers) { return }
            $tools = if ($Tool -eq 'all') { @('claude', 'codex', 'opencode', 'vscode', 'cursor') } else { @($Tool) }
            foreach ($t in $tools) {
                switch ($t) {
                    'claude'   { Install-McpToClaude $servers }
                    'codex'    { Install-McpToCodex $servers }
                    'opencode' { Install-McpToOpenCode $servers }
                    'vscode'   { Install-McpToVSCode $servers }
                    'cursor'   { Install-McpToCursor $servers }
                }
            }
        }
        default { Write-Error "不明なアクション: $Action (export / sync / install)" }
    }
}

# ---- pera: モデル起動の選択式メニュー ----
function Open-Editor {
    param([string]$Editor)
    $cwd = Get-Location
    switch ($Editor) {
        'vscode' {
            if (Get-Command code -ErrorAction SilentlyContinue) { code $cwd }
            elseif ($IsWindows) { Start-Process "code" -ArgumentList $cwd }
            else { Start-Process "code" -ArgumentList $cwd }
        }
        'cursor' {
            if (Get-Command cursor -ErrorAction SilentlyContinue) { cursor $cwd }
            elseif ($IsWindows) { Start-Process "cursor" -ArgumentList $cwd }
            else { Start-Process "cursor" -ArgumentList $cwd }
        }
    }
}

function pera {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Model,
        [Parameter(Position = 1)]
        [string]$McpAction,
        [switch]$List,
        [switch]$Launch,
        [switch]$Run,
        [switch]$Mcp
    )

    if ($Mcp -or $Model -eq 'mcp') {
        pera-mcp $McpAction
        return
    }

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
        Write-Host "  2) claude   ... claude で起動"
        Write-Host "  3) codex    ... codex で起動"
        Write-Host "  4) vscode   ... VS Code で開く"
        Write-Host "  5) cursor   ... Cursor で開く"
        Write-Host "  6) run      ... ollama run で起動（初回取得用）"
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
            if ($yolo -match '^[yY]') { codex --oss --local-provider ollama -m $tag --dangerously-bypass-approvals-and-sandbox }
            else { codex --oss --local-provider ollama -m $tag }
            return
        }
        elseif ($choice -eq '4') { Open-Editor 'vscode'; return }
        elseif ($choice -eq '5') { Open-Editor 'cursor'; return }
        elseif ($choice -eq '6') { $Run = $true }
        else {
            Write-Error "無効な番号です。"
            return
        }
    }

    if ($Launch) { ollama launch opencode --model $tag }
    elseif ($Run) { ollama run $tag }
}
