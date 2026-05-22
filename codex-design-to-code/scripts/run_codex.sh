#!/bin/bash
# Usage: run_codex.sh <prompt_file>
#
# Codex CLI を「ファイル経由 + stdin クローズ」で起動する。
# argv で長いプロンプトを直接渡すと exit 144 で失敗する事例があるためのワークアラウンド。
# 同期実行する（バックグラウンド化は呼び出し側で & をつけるか run_in_background で）。

set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 <prompt_file>" >&2
  exit 2
fi

PROMPT_FILE="$1"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi

codex exec --skip-git-repo-check --sandbox workspace-write "$(cat "$PROMPT_FILE")" < /dev/null
