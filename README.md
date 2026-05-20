# claude-task-reporter

Claude Code がタスクを完了したタイミングで、作業内容を Haiku で要約し、macOS のデスクトップ通知と音声読み上げで報告する Stop フック。

音声読み上げは、VOICEVOX (ずんだもん) が利用可能であればそちらを優先し、未起動時は macOS 標準の `say` にフォールバックする。

## 動作概要

- Claude Code の Stop イベント（1つの指示への応答が完了したとき）に発火
- セッションのトランスクリプトを `claude-haiku` で要約
- macOS のデスクトップ通知（`osascript`）と音声読み上げで通知
- SessionStart イベントで `CS_ENABLED` 設定に応じて VOICEVOX コンテナを自動起動／停止

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

必要に応じて `CS_ENABLED=true` に変更する。

### 3. settings.json に hook を登録

`~/.claude/settings.json` の `hooks` に以下を追加（`settings.json.example` 参照）：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-task-reporter/voicevox_sync.sh",
            "timeout": 10
          }
        ]
      }
    ],
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
CS_ENABLED=true   # 有効
CS_ENABLED=false  # 無効
```

`bin/` 以下のスクリプトを PATH に追加することで、コマンドから操作できる：

```bash
export PATH="$HOME/.claude/hooks/claude-task-reporter/bin:$PATH"
```

| コマンド | 説明 |
|---|---|
| `csconfig` | ON/OFF をトグル |
| `csstatus` | 現在の状態を表示 |

## VOICEVOX (ずんだもん) 連携

`session_summary.conf` の `CS_VOICE_MODE` で音声出力を切り替えられる:

| 値 | 挙動 |
|---|---|
| `auto` (デフォルト) | VOICEVOX ENGINE が起動していればずんだもん、停止中は `say` にフォールバック |
| `say` | 常に `say` を使用 |
| `zundamon` | 常にずんだもん。ENGINE 未起動時は読み上げをスキップ |

SessionStart hook (`voicevox_sync.sh`) が `CS_ENABLED` の値を見て VOICEVOX コンテナの起動／停止を自動制御する:

- `CS_ENABLED=true`  → コンテナが未起動なら `docker run` で起動
- `CS_ENABLED=false` → コンテナが起動中なら `docker stop` で停止

初回のみ Docker Hub から `voicevox/voicevox_engine:cpu-latest` (約 2-3GB) を pull するため数十秒〜数分かかる。2回目以降は数秒で起動。

クレジット表記: 本機能は [VOICEVOX:ずんだもん] を利用している。

## 動作要件

- macOS（`osascript`, `say`, `afplay` を使用）
- [Claude Code CLI](https://claude.ai/code) がインストール済みであること
- `jq` コマンド
- `curl` コマンド
- Docker (VOICEVOX 連携を使う場合のみ)
