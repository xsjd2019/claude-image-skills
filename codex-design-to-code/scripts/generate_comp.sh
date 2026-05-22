#!/bin/bash
# Usage: generate_comp.sh <slug> <prompt-template-file> [output-path] [timeout-seconds]
#
# Phase 1 — Design comp（全画面1枚PNG）を生成する。
# プロンプト中の {{PNG_PATH}} を実パスに置換してから codex を起動、PNG出現を待って結果を返す。
#
# 引数:
#   slug                  : 内容を表す英語スラッグ（例: lp-oripa, dashboard-admin）
#   prompt-template-file  : {{PNG_PATH}} プレースホルダー入りのプロンプト
#   output-path           : (任意) PNG の最終保存先。省略時は /tmp/comp-<slug>-<timestamp>.png
#   timeout-seconds       : (任意) 待機タイムアウト。デフォルト 600（10分。LP comp は時間かかる）
#
# 終了コード:
#   0: 成功（最終行に PNG パスを echo）
#   1: タイムアウト or サイズ異常
#   2: 引数エラー

set -e

if [ $# -lt 2 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <slug> <prompt-template-file> [output-path] [timeout-seconds]" >&2
  exit 2
fi

SLUG="$1"
PROMPT_TEMPLATE="$2"
TIMESTAMP=$(date "+%Y%m%d-%H%M")
OUTPUT_PATH="${3:-/tmp/comp-${SLUG}-${TIMESTAMP}.png}"
TIMEOUT="${4:-600}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$PROMPT_TEMPLATE" ]; then
  echo "Error: prompt template not found: $PROMPT_TEMPLATE" >&2
  exit 2
fi

PROMPT_FINAL="/tmp/codex-prompt-comp-${SLUG}-${TIMESTAMP}.txt"
CODEX_LOG="/tmp/codex-log-comp-${SLUG}-${TIMESTAMP}.txt"

echo "→ Comp slug: $SLUG" >&2
echo "→ Output:    $OUTPUT_PATH" >&2

# {{PNG_PATH}} を実パスに置換
sed "s|{{PNG_PATH}}|${OUTPUT_PATH}|g" "$PROMPT_TEMPLATE" > "$PROMPT_FINAL"

# codex バックグラウンド起動
echo "→ Codex 起動中..." >&2
"$SCRIPT_DIR/run_codex.sh" "$PROMPT_FINAL" > "$CODEX_LOG" 2>&1 &
CODEX_PID=$!

# PNG 出現待ち（タイムアウト + サイズ検証）
if ! "$SCRIPT_DIR/wait_for_png.sh" "$OUTPUT_PATH" "$TIMEOUT"; then
  echo "失敗: PNG 生成タイムアウト or サイズ異常" >&2
  echo "--- Codex log (tail 30) ---" >&2
  tail -30 "$CODEX_LOG" >&2 || true
  kill "$CODEX_PID" 2>/dev/null || true
  exit 1
fi

wait "$CODEX_PID" 2>/dev/null || true

# 結果報告（最終行にパスのみ）
echo "$OUTPUT_PATH"
