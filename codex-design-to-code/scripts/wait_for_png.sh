#!/bin/bash
# Usage: wait_for_png.sh <target_path> [timeout_seconds]
#
# target_path のファイルが出現し、かつサイズが MIN_SIZE 以上になるまで待つ。
# タイムアウトしたら exit 1。サイズ検証により、空ファイル・破損ファイルでの誤検知を防ぐ。

set -e

TARGET="$1"
TIMEOUT="${2:-300}"
MIN_SIZE=10000  # 10KB 未満は破損とみなす

if [ -z "$TARGET" ]; then
  echo "Usage: $0 <target_path> [timeout_seconds]" >&2
  exit 2
fi

START=$(date +%s)

while true; do
  if [ -f "$TARGET" ] && [ "$(stat -f%z "$TARGET" 2>/dev/null || echo 0)" -gt "$MIN_SIZE" ]; then
    echo "ok: $(stat -f%z "$TARGET") bytes"
    exit 0
  fi
  if [ $(( $(date +%s) - START )) -gt "$TIMEOUT" ]; then
    echo "TIMEOUT after ${TIMEOUT}s (target=$TARGET)" >&2
    exit 1
  fi
  sleep 5
done
