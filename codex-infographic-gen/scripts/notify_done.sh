#!/bin/bash
# Usage: notify_done.sh <filename> [size]
#
# macOS の無音通知を出す（音は鳴らさない）。
# 通知センターに残るので、別作業中でも完了に気付ける。

set -e

FILENAME="$1"
SIZE="${2:-}"

if [ -z "$FILENAME" ]; then
  echo "Usage: $0 <filename> [size]" >&2
  exit 2
fi

TITLE="インフォグラフィック完成"
SUBTITLE="~/Downloads/ に保存しました"

if [ -n "$SIZE" ]; then
  MSG="$FILENAME ($SIZE)"
else
  MSG="$FILENAME"
fi

# osascript エラーは致命的ではない（通知が出ないだけ）ので失敗を吸収
osascript -e "display notification \"$MSG\" with title \"$TITLE\" subtitle \"$SUBTITLE\"" 2>/dev/null || true
