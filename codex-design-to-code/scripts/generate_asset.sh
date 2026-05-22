#!/bin/bash
# Usage: generate_asset.sh <slug> <asset-name> <prompt-template-file> <comp-path> [final-dir] [timeout-seconds]
#
# Phase 2 — 分割アセット1個を生成する。カンプを参照画像として渡し、整合する素材を作る。
# Claude はこのスクリプトを N 個並列で呼ぶ（各 run_in_background）。
#
# 引数:
#   slug                  : LP / 画面の識別子（例: lp-oripa）
#   asset-name            : このアセットの名前（例: hero-bg, icon-truck, brand-mark）
#   prompt-template-file  : {{PNG_PATH}} と {{COMP_PATH}} プレースホルダー入りプロンプト
#   comp-path             : Phase 1 で生成したカンプ PNG の絶対パス
#   final-dir             : (任意) 完成後の cp 先ディレクトリ（例: <project>/public/images）
#                            省略時は /tmp に置きっぱなし（Claude が後処理）
#   timeout-seconds       : (任意) 待機タイムアウト。デフォルト 300（5分）
#
# 終了コード:
#   0: 成功（最終行にアセット PNG の最終パスを echo）
#   1: タイムアウト or サイズ異常
#   2: 引数エラー
#   3: cp 失敗

set -e

if [ $# -lt 4 ] || [ $# -gt 6 ]; then
  echo "Usage: $0 <slug> <asset-name> <prompt-template-file> <comp-path> [final-dir] [timeout-seconds]" >&2
  exit 2
fi

SLUG="$1"
ASSET_NAME="$2"
PROMPT_TEMPLATE="$3"
COMP_PATH="$4"
FINAL_DIR="${5:-}"
TIMEOUT="${6:-300}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$PROMPT_TEMPLATE" ]; then
  echo "Error: prompt template not found: $PROMPT_TEMPLATE" >&2
  exit 2
fi
if [ ! -f "$COMP_PATH" ]; then
  echo "Error: comp PNG not found: $COMP_PATH" >&2
  exit 2
fi

# Codex サンドボックスは /tmp 書き込みが安定するので、まず /tmp に保存
INTERMEDIATE_PATH="/tmp/${SLUG}-${ASSET_NAME}.png"
PROMPT_FINAL="/tmp/codex-prompt-${SLUG}-${ASSET_NAME}.txt"
CODEX_LOG="/tmp/codex-log-${SLUG}-${ASSET_NAME}.txt"

echo "→ Asset: $SLUG / $ASSET_NAME" >&2
echo "→ Comp:  $COMP_PATH (reference)" >&2
echo "→ Intermediate: $INTERMEDIATE_PATH" >&2

# {{PNG_PATH}} と {{COMP_PATH}} を置換
sed -e "s|{{PNG_PATH}}|${INTERMEDIATE_PATH}|g" \
    -e "s|{{COMP_PATH}}|${COMP_PATH}|g" \
    "$PROMPT_TEMPLATE" > "$PROMPT_FINAL"

# codex バックグラウンド起動
echo "→ Codex 起動中..." >&2
"$SCRIPT_DIR/run_codex.sh" "$PROMPT_FINAL" > "$CODEX_LOG" 2>&1 &
CODEX_PID=$!

# PNG 出現待ち
if ! "$SCRIPT_DIR/wait_for_png.sh" "$INTERMEDIATE_PATH" "$TIMEOUT"; then
  echo "失敗: アセット生成タイムアウト or サイズ異常 ($ASSET_NAME)" >&2
  echo "--- Codex log (tail 30) ---" >&2
  tail -30 "$CODEX_LOG" >&2 || true
  kill "$CODEX_PID" 2>/dev/null || true
  exit 1
fi

wait "$CODEX_PID" 2>/dev/null || true

# final-dir 指定があれば cp（race condition 回避のため codex 完全終了を待ってから）
if [ -n "$FINAL_DIR" ]; then
  mkdir -p "$FINAL_DIR"
  FINAL_PATH="${FINAL_DIR%/}/${ASSET_NAME}.png"
  if ! cp "$INTERMEDIATE_PATH" "$FINAL_PATH"; then
    echo "失敗: cp $INTERMEDIATE_PATH → $FINAL_PATH" >&2
    exit 3
  fi
  echo "$FINAL_PATH"
else
  echo "$INTERMEDIATE_PATH"
fi
