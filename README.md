# claude-task-reporter

Claude Code がタスクを完了したタイミングで、セッションのトランスクリプトを `claude-haiku` または `agy` (Gemini) で要約し、macOS のデスクトップ通知と音声読み上げで報告する Stop フック。

音声読み上げは、VOICEVOX (ずんだもん) が利用可能であればそちらを優先し、未起動時は macOS 標準の `say` にフォールバックする。

---

## 動作要件

**セットアップ前に、以下がすべて揃っていることを確認してください。**

| 要件 | インストール方法 |
|---|---|
| macOS | `osascript`, `say`, `afplay` を使用するため macOS 必須 |
| [Claude Code CLI](https://claude.ai/code) | `npm install -g @anthropic-ai/claude-code` |
| `agy` | `agy` を使用する場合のみ必要 |
| `jq` | `brew install jq` |
| `curl` | macOS 標準搭載（通常インストール不要） |
| Docker | [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) ※ VOICEVOX 連携を使う場合のみ |

---

## セットアップ（初回のみ）

### Step 1. リポジトリをクローン

```bash
git clone git@github.com:ryokwkm/claude-task-reporter.git ~/.claude/hooks/claude-task-reporter
```

### Step 2. settings.json に hook を登録

`~/.claude/settings.json` の `hooks` に以下を追加（`settings.json.example` 参照）：

```json
{
  "hooks": {
    "UserPromptSubmit": [
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

### Step 3. 設定ファイルを作成（必須）

`.example` をコピーして `session_summary.conf` を作る:

```bash
cp ~/.claude/hooks/claude-task-reporter/session_summary.conf.example \
   ~/.claude/hooks/claude-task-reporter/session_summary.conf
```

デフォルトで `CS_ENABLED=true`（有効）になっている。無効にしたい場合は `CS_ENABLED=false` に書き換える。

### Step 4. PATH を通す（任意）

設定の ON/OFF や状態確認を1コマンドで行いたい場合は、`bin/` を PATH に追加する:

```bash
export PATH="$HOME/.claude/hooks/claude-task-reporter/bin:$PATH"
```

`~/.zshrc` などに追記すると永続化される。

| コマンド | 説明 |
|---|---|
| `csconfig` | ON/OFF をトグル |
| `csstatus` | 現在の状態を表示 |
| `csedit` | 設定ファイルを vi で開く |

---

## LLM プロバイダーの切り替え

`session_summary.conf` の `CS_LLM_PROVIDER` で、要約に使用する LLM を切り替えることができます。

| 値 | 説明 |
|---|---|
| `claude` (デフォルト) | `claude` コマンド (`haiku` モデル) を使用 |
| `agy` | `agy` コマンド (Gemini) を使用 |

---

## VOICEVOX (ずんだもん) 連携

`session_summary.conf` の `CS_VOICE_MODE` で音声出力を切り替えられる:

| 値 | 挙動 |
|---|---|
| `auto` (デフォルト) | VOICEVOX ENGINE が起動していればずんだもん、停止中は `say` にフォールバック |
| `say` | 常に `say` を使用 |
| `zundamon` | 常にずんだもん。ENGINE 未起動時は読み上げをスキップ |

UserPromptSubmit hook (`voicevox_sync.sh`) が `CS_ENABLED` の値を見て VOICEVOX コンテナの起動／停止を自動制御する:

- `CS_ENABLED=true`  → コンテナが未起動なら `docker run` で起動
- `CS_ENABLED=false` → コンテナが起動中なら `docker stop` で停止

初回のみ Docker Hub から `voicevox/voicevox_engine:cpu-latest` (約 2-3GB) を pull するため数十秒〜数分かかる。2回目以降は数秒で起動。

クレジット表記: 本機能は [VOICEVOX:ずんだもん] を利用している。

