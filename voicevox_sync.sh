#!/bin/bash
# voicevox_sync.sh
# Claude Code の SessionStart イベントで呼び出され、
# session_summary.conf の CS_ENABLED 設定と VOICEVOX コンテナの起動状態を同期する
#
# - CS_ENABLED=true  かつ コンテナ停止中 → docker run でコンテナを起動
# - CS_ENABLED=false かつ コンテナ起動中 → docker stop でコンテナを停止
# - 状態が一致していれば何もしない
#
# SessionStart hook を待たせないため、self-fork でバックグラウンド実行する

# self-fork: 親プロセスは即座に終了し、子プロセスで実処理を継続
if [ -z "${VOICEVOX_SYNC_FORKED:-}" ]; then
    VOICEVOX_SYNC_FORKED=1 nohup "$0" "$@" >/tmp/voicevox_sync.log 2>&1 &
    exit 0
fi

# ----- 子プロセスでの実処理 -----
SCRIPT_DIR=$(dirname "$0")
CONF="${SCRIPT_DIR}/session_summary.conf"

if [ ! -f "$CONF" ]; then
    echo "[voicevox_sync] 設定ファイルが見つかりません: $CONF" >&2
    exit 0
fi

. "$CONF"

if ! command -v docker >/dev/null 2>&1; then
    echo "[voicevox_sync] docker コマンドが見つかりません。スキップします。" >&2
    exit 0
fi

CONTAINER_NAME="${VOICEVOX_CONTAINER:-voicevox_engine}"
IMAGE="${VOICEVOX_IMAGE:-voicevox/voicevox_engine:cpu-latest}"

is_running() {
    [ -n "$(docker ps -q -f "name=^${CONTAINER_NAME}$" 2>/dev/null)" ]
}

start_container() {
    echo "[voicevox_sync] VOICEVOX コンテナを起動: ${CONTAINER_NAME}" >&2
    docker run --rm -d \
        --name "$CONTAINER_NAME" \
        -p 127.0.0.1:50021:50021 \
        "$IMAGE" >/dev/null
}

stop_container() {
    echo "[voicevox_sync] VOICEVOX コンテナを停止: ${CONTAINER_NAME}" >&2
    docker stop "$CONTAINER_NAME" >/dev/null
}

if [ "${CS_ENABLED:-false}" = "true" ]; then
    if ! is_running; then
        start_container
    else
        echo "[voicevox_sync] コンテナは既に起動中。スキップ。" >&2
    fi
else
    if is_running; then
        stop_container
    else
        echo "[voicevox_sync] コンテナは既に停止中。スキップ。" >&2
    fi
fi

exit 0
