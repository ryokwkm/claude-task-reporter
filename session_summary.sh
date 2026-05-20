#!/bin/bash
# session_summary.sh
# Claude Code の Stop イベントで呼び出され、作業内容を LLM で要約するスクリプト
# 要約結果をデスクトップ通知・音声読み上げで提供する

SCRIPT_DIR=$(dirname "$0")

if [ -f "${SCRIPT_DIR}/session_summary.conf" ]; then
    . "${SCRIPT_DIR}/session_summary.conf"
fi
if [ "${ENABLED:-true}" != "true" ]; then
    exit 0
fi

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

say "$SUMMARY_RESULT" &
echo "[session_summary] 音声読み上げをバックグラウンドで開始しました" >&2

if [ $((RANDOM % 100)) -lt 3 ]; then
    find /tmp -name "claude_summary_*.txt" -mtime +1 -delete 2>/dev/null
    find /tmp -name "claude_hook_debug.json" -mtime +1 -delete 2>/dev/null
    echo "[session_summary] 古いファイルをクリーンアップしました" >&2
fi

exit 0
