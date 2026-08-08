# pera

**P**ick **E**asy **R**un **A**gents — AI エージェント（claude / codex / opencode）を簡単に選んで起動するツールです。

PowerShell / bash で Ollama モデルと AI CLI（claude / codex）を選択式メニューから起動します。

Windows と macOS の両方に対応しています。

## 機能

- **モデル選択メニュー**: `pera` を実行すると Ollama モデル一覧から選択できます
- **claude / codex 起動**: モデル選択メニューから claude（dangerous モード対応）と codex（yolo モード対応）も起動できます
- **起動方法の選択**: opencode（`ollama launch`）/ claude / codex / run（`ollama run`）から選択
- **ショートカット関数**: モデルごとに `launch-<model>` / `run-<model>` を自動生成

## 必要環境

| ツール | 用途 |
| --- | --- |
| [Ollama](https://ollama.com/) | opencode / run を使う場合 |
| [Claude Code](https://claude.com/) | claude を使う場合 |
| [Codex](https://openai.com/codex/) | codex を使う場合 |

## インストール

### Windows (PowerShell)

ターミナルで以下を実行するだけで、`~/.pera/pera.ps1` に配置してプロファイルへ自動登録します。

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.pera" | Out-Null; iwr https://raw.githubusercontent.com/yushimatenjin/pera/master/pera.ps1 -OutFile "$HOME\.pera\pera.ps1"; Add-Content -Path $PROFILE -Value '. "$HOME\.pera\pera.ps1"'; . $PROFILE
```

### macOS (bash / zsh)

ターミナルで以下を実行するだけで、`~/.pera/pera.sh` に配置して `~/.zshrc`（または `~/.bashrc`）へ自動登録します。

```bash
mkdir -p ~/.pera && curl -fsSL https://raw.githubusercontent.com/yushimatenjin/pera/master/pera.sh -o ~/.pera/pera.sh && echo 'source ~/.pera/pera.sh' >> ~/.zshrc && source ~/.zshrc
```

> 手動で入れる場合は、`pera.ps1`（Windows）または `pera.sh`（macOS）をプロファイルから読み込んでください。

## 使い方

```powershell
pera                  # モデルと起動方法を選択して実行
pera -list            # モデル一覧を表示
pera -launch <model>  # 直接 launch で起動
pera -run <model>     # 直接 run で起動
launch-<model>        # モデルごとの launch ショートカット
run-<model>           # モデルごとの run ショートカット
```

### 起動方法メニュー

モデルを選ぶと、起動方法を選択できます。

| 番号 | 起動方法 | コマンド |
| --- | --- | --- |
| 1 | opencode | `ollama launch opencode --model <tag>` |
| 2 | claude | `claude`（dangerous モード確認あり） |
| 3 | codex | `codex`（yolo モード確認あり） |
| 4 | run | `ollama run <tag>` |

claude を選ぶと dangerous モード（`--dangerously-skip-permissions`）を、codex を選ぶと yolo モード（`--dangerously-bypass-approvals-and-sandbox`）を使うか確認されます。

## モデルの追加

`pera.ps1`（Windows）または `pera.sh`（macOS）のモデル定義に追記します。

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
