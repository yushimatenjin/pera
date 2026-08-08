# pera

PowerShell で Ollama モデルと AI CLI（claude / codex）を選択式メニューから起動するツールです。

## 機能

- **モデル選択メニュー**: `pera` を実行すると Ollama モデル一覧から選択できます
- **claude / codex 起動**: モデル選択メニューから claude（dangerous モード対応）と codex（yolo モード対応）も起動できます
- **起動方法の選択**: opencode（`ollama launch`）/ claude / codex / run（`ollama run`）から選択
- **ショートカット関数**: モデルごとに `launch-<model>` / `run-<model>` を自動生成

## 必要環境

- PowerShell 7+
- [Ollama](https://ollama.com/)（opencode / run を使う場合）
- [Claude Code](https://claude.com/)（claude を使う場合）
- [Codex](https://openai.com/codex/)（codex を使う場合）

## インストール

`pera.ps1` をプロファイルから読み込みます。

```powershell
# プロファイルに追加
Add-Content -Path $PROFILE -Value '. "C:\path\to\pera.ps1"'
```

または、プロファイルに直接貼り付けて使うこともできます。

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

`pera.ps1` の `$script:OllamaModels` ハッシュテーブルに追記します。

```powershell
$script:OllamaModels = @{
    'glm-5.2' = 'glm-5.2:cloud'
    # ここに追加
}
```

## ライセンス

[MIT](./LICENSE)
