# claude-task-reporter

Claude Code がタスクを完了したタイミングで、作業内容を Haiku で要約し、macOS のデスクトップ通知と音声読み上げで報告する Stop フック。

## 動作概要

- Claude Code の Stop イベント（1つの指示への応答が完了したとき）に発火
- セッションのトランスクリプトを `claude-haiku` で要約
- macOS のデスクトップ通知（`osascript`）と音声読み上げ（`say`）で通知

## インストール

### 1. リポジトリをクローン

```bash
git clone git@github.com:ryokwkm/claude-task-reporter.git ~/.claude/hooks/claude-task-reporter
```

または既存リポジトリの submodule として追加：

```bash
git submodule add git@github.com:ryokwkm/claude-task-reporter.git path/to/claude-task-reporter
```

### 2. 設定ファイルを作成

```bash
cp ~/.claude/hooks/claude-task-reporter/session_summary.conf.example \
   ~/.claude/hooks/claude-task-reporter/session_summary.conf
```

必要に応じて `ENABLED=true` に変更する。

### 3. settings.json に hook を登録

`~/.claude/settings.json` の `hooks` に以下を追加（`settings.json.example` 参照）：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-task-reporter/session_summary.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

## 設定

`session_summary.conf` で ON/OFF を切り替えられる：

```bash
ENABLED=true   # 有効
ENABLED=false  # 無効
```

`bin/` 以下のスクリプトを PATH に追加することで、コマンドから操作できる：

```bash
export PATH="$HOME/.claude/hooks/claude-task-reporter/bin:$PATH"
```

| コマンド | 説明 |
|---|---|
| `gs-config` | ON/OFF をトグル |
| `gs-status` | 現在の状態を表示 |

## 動作要件

- macOS（`osascript`, `say` を使用）
- [Claude Code CLI](https://claude.ai/code) がインストール済みであること
- `jq` コマンド
