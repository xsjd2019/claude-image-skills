#!/bin/bash
# Usage: generate.sh <slug> <prompt-template-file>
#
# インフォグラフィック生成パイプラインを一発で実行する:
#   codex 起動 → PNG出現待ち → WebP変換 → 完了通知 → 結果報告
#
# prompt-template-file は中で {{PNG_PATH}} プレースホルダーを使うこと。
# このスクリプトが実パスに置換して最終プロンプトを /tmp に保存する。
#
# 出力サイズ:
#   gpt-image-2 portrait は 1024x1536 (1:1.5) を採用。A4 portrait (1:1.4142) より
#   6% ほど縦に長いが、A4 風の縦長文書ビジュアルとしては十分。クロップは行わない
#   （codex がピクセル境界を厳守できず content loss が起きやすいため）。
#
# 終了コード:
#   0: 成功
#   1: codex ハング・タイムアウト
#   2: 引数エラー
#   3: 変換失敗

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <slug> <prompt-template-file>" >&2
  echo "  slug: 内容を表す英語スラッグ (kebab-case)、例: skill-overview" >&2
  echo "        複数枚なら -p1of3 のようにページ番号を含める" >&2
  echo "  prompt-template-file: {{PNG_PATH}} プレースホルダー入りのプロンプト" >&2
  exit 2
fi

SLUG="$1"
PROMPT_TEMPLATE="$2"
TIMESTAMP=$(date "+%Y%m%d-%H%M")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$PROMPT_TEMPLATE" ]; then
  echo "Error: prompt template not found: $PROMPT_TEMPLATE" >&2
  exit 2
fi

PNG_PATH="/tmp/infographic-${SLUG}-${TIMESTAMP}.png"
WEBP_PATH="$HOME/Downloads/infographic-${SLUG}-${TIMESTAMP}.webp"
PROMPT_FINAL="/tmp/codex-prompt-${SLUG}-${TIMESTAMP}.txt"
CODEX_LOG="/tmp/codex-log-${SLUG}-${TIMESTAMP}.txt"

echo "→ Slug: $SLUG / Timestamp: $TIMESTAMP"
echo "→ PNG:  $PNG_PATH"
echo "→ WebP: $WEBP_PATH"

# Step 1: テンプレートのプレースホルダーを実パスに置換
sed "s|{{PNG_PATH}}|${PNG_PATH}|g" "$PROMPT_TEMPLATE" > "$PROMPT_FINAL"

# Step 2: codex をバックグラウンド起動
echo "→ Codex 起動中..."
"$SCRIPT_DIR/run_codex.sh" "$PROMPT_FINAL" > "$CODEX_LOG" 2>&1 &
CODEX_PID=$!

# Step 3: PNG 出現を待つ（タイムアウト + サイズ検証）
if ! "$SCRIPT_DIR/wait_for_png.sh" "$PNG_PATH" 300; then
  echo "失敗: PNG 生成タイムアウト or サイズ異常" >&2
  echo "--- Codex log (tail 30) ---" >&2
  tail -30 "$CODEX_LOG" >&2 || true
  echo "--- エラーパターン ---" >&2
  grep -nE "Error|Failed|denied|refused|sandbox|exit" "$CODEX_LOG" | head -10 >&2 || true
  kill "$CODEX_PID" 2>/dev/null || true
  exit 1
fi

wait "$CODEX_PID" 2>/dev/null || true

# Step 4: WebP 変換（image-compress スキルを呼び出す。near-lossless 既定で品質維持）
echo "→ WebP 変換中..."
COMPRESS_SH="$HOME/.claude/skills/image-compress/scripts/compress.sh"
if [ ! -x "$COMPRESS_SH" ]; then
  echo "失敗: image-compress スキルが見つからない: $COMPRESS_SH" >&2
  echo "Hint: ~/.claude/skills/image-compress/ をインストールしてください" >&2
  exit 3
fi
if ! "$COMPRESS_SH" "$PNG_PATH" "$WEBP_PATH"; then
  echo "失敗: WebP 変換エラー" >&2
  exit 3
fi

# Step 5: 完了通知（無音）
SIZE=$(ls -lh "$WEBP_PATH" | awk '{print $5}')
"$SCRIPT_DIR/notify_done.sh" "$(basename "$WEBP_PATH")" "$SIZE"

# Step 6: 結果報告
echo ""
echo "✅ $WEBP_PATH ($SIZE)"
