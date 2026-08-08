# pera

**P**ick **E**asy **R**un **A**gents — AI エージェントを選んで起動する、シンプルなランチャーです。

`pera` を実行すると、モデルやツールを番号で選ぶだけで起動できます。MCP サーバーの設定も、各ツールへの同期をまとめて行えます。

Windows（PowerShell）と macOS（bash / zsh）の両方に対応しています。

## インストール

### Windows (PowerShell)

ターミナルで以下を実行するだけで、`~/.pera/pera.ps1` に配置してプロファイルへ自動登録します。

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.pera" | Out-Null
iwr https://raw.githubusercontent.com/yushimatenjin/pera/master/src/pera.ps1 -OutFile "$HOME\.pera\pera.ps1"
Add-Content -Path $PROFILE -Value '. "$HOME\.pera\pera.ps1"'
. $PROFILE
```

### macOS (bash / zsh)

ターミナルで以下を実行するだけで、`~/.pera/pera.sh` に配置して `~/.zshrc`（または `~/.bashrc`）へ自動登録します。

```bash
mkdir -p ~/.pera
curl -fsSL https://raw.githubusercontent.com/yushimatenjin/pera/master/src/pera.sh -o ~/.pera/pera.sh
echo 'source ~/.pera/pera.sh' >> ~/.zshrc
source ~/.zshrc
```

## 使い方

`pera` を実行すると、モデル一覧から番号で選ぶだけです。

```
モデルを選択してください:
 1) deepseek-v4-flash    deepseek-v4-flash:0731-cloud
 2) deepseek-v4-pro      deepseek-v4-pro:cloud
 3) gemma4               gemma4:cloud
 4) glm-5.1              glm-5.1:cloud
 5) glm-5.2              glm-5.2:cloud
 6) gpt-oss              gpt-oss:cloud
 7) kimi-k2.6            kimi-k2.6:cloud
 8) kimi-k2.7-code       kimi-k2.7-code:cloud
 9) kimi-k3              kimi-k3:cloud
10) minimax-m2.7         minimax-m2.7:cloud
11) minimax-m3           minimax-m3:cloud
12) mistral-large-3      mistral-large-3:cloud
13) nemotron-3-nano      nemotron-3-nano:cloud
14) nemotron-3-super     nemotron-3-super:cloud
15) nemotron-3-ultra     nemotron-3-ultra:cloud
16) qwen3.5              qwen3.5:397b-cloud
17) claude
18) codex
番号を入力 (0 でキャンセル):
```

モデルを選ぶと、起動方法も番号で選べます。

```
起動方法を選択してください (glm-5.2):
  1) opencode ... ollama launch opencode で起動
  2) claude   ... claude で起動
  3) codex    ... codex で起動
  4) vscode   ... VS Code で開く
  5) cursor   ... Cursor で開く
  6) run      ... ollama run で起動（初回取得用）
番号を入力 (0 でキャンセル):
```

claude を選ぶと dangerous モード、codex を選ぶと yolo モードを使うか確認されます。

## MCP サーバー管理

`pera mcp` で、各ツール（claude / codex / opencode / vscode / cursor）の MCP サーバー設定を一元管理できます。

`mcp.json` にサーバー定義（`command` / `args` / `env`）を書き、各ツールの設定ファイルに配布します。

```powershell
pera mcp export   # 各ツールの MCP 設定を吸い出して mcp.json に集約
pera mcp sync     # mcp.json を全ツールに配布
pera mcp install  # mcp.json を指定ツールに配布
```

### mcp.json の形式

```json
{
  "servers": {
    "server-name": {
      "command": "npx",
      "args": ["@playwright/mcp"],
      "env": {}
    }
  }
}
```

### 対応ツールと設定ファイル

| ツール | 設定ファイル |
| --- | --- |
| claude | `~/.claude.json` |
| codex | `~/.codex/config.toml` |
| opencode | `~/.config/opencode/opencode.json` |
| vscode | `.vscode/mcp.json`（プロジェクト単位） |
| cursor | `~/.cursor/mcp.json` |

## モデルの追加

`src/pera.ps1`（Windows）または `src/pera.sh`（macOS）のモデル定義に追記します。

### Windows (PowerShell)

```powershell
$script:OllamaModels = @{
    'glm-5.2' = 'glm-5.2:cloud'
    # ここに追加
}
```

### macOS (bash)

```bash
declare -A OLLAMA_MODELS=(
    ['glm-5.2']='glm-5.2:cloud'
    # ここに追加
)
```

## ライセンス

[MIT](./LICENSE)
