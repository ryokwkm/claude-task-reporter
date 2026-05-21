#!/bin/bash
# session_summary.sh
# Claude Code の Stop イベントで呼び出され、作業内容を LLM で要約するスクリプト
# 要約結果をデスクトップ通知・音声読み上げで提供する

SCRIPT_DIR=$(dirname "$0")

if [ -f "${SCRIPT_DIR}/session_summary.conf" ]; then
    . "${SCRIPT_DIR}/session_summary.conf"
fi
if [ "${CS_ENABLED:-true}" != "true" ]; then
    exit 0
fi

AUDIO_PID=""

cleanup() {
    [ -n "$AUDIO_PID" ] && kill "$AUDIO_PID" 2>/dev/null
    exit 0
}
trap cleanup INT TERM

# Claude Code から stdin で渡される JSON を受け取る（shに専用の組み込み変数はなく、cat がイディオム）
ARGS=$(cat)

echo "$ARGS" > /tmp/claude_hook_debug.json

TRANSCRIPT_PATH=$(echo "$ARGS" | jq -r '.transcript_path // empty' 2>/dev/null)
SESSION_ID=$(echo "$ARGS" | jq -r '.session_id // empty' 2>/dev/null)
STOP_REASON=$(echo "$ARGS" | jq -r '.stop_reason // "end_turn"' 2>/dev/null)

SUMMARY_INPUT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    SUMMARY_INPUT=$(tail -n 30 "$TRANSCRIPT_PATH")
else
    SUMMARY_INPUT=$(echo "$ARGS" | cut -c 1-2000)
fi

if [ -z "$SUMMARY_INPUT" ]; then
    echo "[session_summary] 要約対象データが見つかりませんでした。スキップします。" >&2
    exit 0
fi

PROMPT_PREFIX=$(cat "${SCRIPT_DIR}/session_summary_prompt.txt")
FULL_PROMPT="${PROMPT_PREFIX}
${SUMMARY_INPUT}"

echo "[session_summary] 作業要約を生成中 (stop_reason: ${STOP_REASON})..." >&2

SUMMARY_RESULT=$(claude -p --setting-sources "" --model claude-haiku-4-5 "$FULL_PROMPT" \
    2>/tmp/session_summary_error.log)

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || [ -z "$SUMMARY_RESULT" ]; then
    echo "[session_summary] LLM 要約の実行に失敗しました (exit: ${EXIT_CODE})" >&2
    exit 1
fi

REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
SUMMARY_FILE="/tmp/claude_summary_${REPO_NAME}_${TIMESTAMP}.txt"
echo "$SUMMARY_RESULT" > "$SUMMARY_FILE"
echo "[session_summary] 要約を保存しました: $SUMMARY_FILE" >&2

osascript -e "display notification \"$SUMMARY_RESULT\" with title \"🤖 Claude 作業完了\"" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "[session_summary] デスクトップ通知を表示しました" >&2
else
    echo "[session_summary] デスクトップ通知の表示に失敗しました" >&2
fi

# ===== 音声出力 =====
# CS_VOICE_MODE に応じて、ずんだもん / say を切り替える
# - auto:     ENGINE 疎通 OK ならずんだもん、NG なら say
# - say:      常に say
# - zundamon: 常にずんだもん（ENGINE 未起動なら読み上げスキップ）
CS_VOICE_MODE="${CS_VOICE_MODE:-auto}"
VOICEVOX_URL="${VOICEVOX_URL:-http://localhost:50021}"
VOICEVOX_SPEAKER="${VOICEVOX_SPEAKER:-3}"
VOICEVOX_SYNTH_TIMEOUT="${VOICEVOX_SYNTH_TIMEOUT:-10}"

voicevox_alive() {
    local code
    code=$(curl -s -o /dev/null --max-time 1 -w "%{http_code}" "${VOICEVOX_URL}/version" 2>/dev/null)
    [ "$code" = "200" ]
}

speak_with_zundamon() {
    local text="$1"
    local wav="/tmp/claude_zunda_$$.wav"
    local query
    query=$(curl -s --max-time "$VOICEVOX_SYNTH_TIMEOUT" \
        -X POST "${VOICEVOX_URL}/audio_query?speaker=${VOICEVOX_SPEAKER}" \
        --get --data-urlencode "text=${text}") || return 1
    [ -z "$query" ] && return 1

    curl -s --max-time "$VOICEVOX_SYNTH_TIMEOUT" \
        -H "Content-Type: application/json" \
        -X POST "${VOICEVOX_URL}/synthesis?speaker=${VOICEVOX_SPEAKER}" \
        -d "$query" -o "$wav" || return 1
    [ ! -s "$wav" ] && return 1

    afplay "$wav" &
    AUDIO_PID=$!
    wait $AUDIO_PID
    AUDIO_PID=""
    rm -f "$wav"
}

speak() {
    local text="$1"
    case "$CS_VOICE_MODE" in
        say)
            echo "[session_summary] say で音声読み上げ..." >&2
            say "$text" &
            AUDIO_PID=$!
            wait $AUDIO_PID
            AUDIO_PID=""
            ;;
        zundamon)
            if voicevox_alive; then
                echo "[session_summary] ずんだもん音声で再生..." >&2
                speak_with_zundamon "$text"
            else
                echo "[session_summary] VOICEVOX ENGINE 未起動。zundamon モードのため読み上げをスキップします" >&2
            fi
            ;;
        auto|*)
            if voicevox_alive; then
                echo "[session_summary] ずんだもん音声で再生..." >&2
                speak_with_zundamon "$text" || {
                    say "$text" &
                    AUDIO_PID=$!
                    wait $AUDIO_PID
                    AUDIO_PID=""
                }
            else
                echo "[session_summary] VOICEVOX ENGINE 未起動。say にフォールバックします" >&2
                say "$text" &
                AUDIO_PID=$!
                wait $AUDIO_PID
                AUDIO_PID=""
            fi
            ;;
    esac
}

speak "$SUMMARY_RESULT"

if [ $((RANDOM % 100)) -lt 3 ]; then
    find /tmp -name "claude_summary_*.txt" -mtime +1 -delete 2>/dev/null
    find /tmp -name "claude_hook_debug.json" -mtime +1 -delete 2>/dev/null
    echo "[session_summary] 古いファイルをクリーンアップしました" >&2
fi

exit 0
