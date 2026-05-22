#!/bin/bash
# Usage: compress.sh <input> <output.webp> [mode-option]
#
# 画像を WebP に圧縮する。デフォルトは quality 95 で「視覚的に劣化なし」+「ファイル軽量」のバランス点。
# 他スキル（codex-infographic-gen 等）から `bash <this-path> <in> <out>` で呼び出せる。
#
# モード:
#   --lossless           : 完全可逆圧縮（情報損失ゼロ、ファイル最大）
#   --near-lossless <N>  : 視覚的に劣化なし。N=0-100（小さいほど強圧縮）。default: 60
#   --quality <N>        : 通常のロッシー圧縮。N=0-100。default: 95（視覚的にほぼロスレス）
#
# 引数なし（input/output のみ）→ quality 95 で実行
# テキスト・グラフィックス中心の画像なら quality 95 が最適（near-lossless より小さく視覚的に同等）。
# 厳密なピクセル保存が必要なら --lossless を明示する。
#
# フォールバック順: cwebp → sips → pngquant
#   cwebp:    Homebrew で brew install webp（一番安定、全モード対応）
#   sips:     macOS 標準（ロッシーのみ対応、書き出し不安定）
#   pngquant: WebP 不可。PNG 圧縮で代替（拡張子が .png に変わる）
#
# 入力形式: PNG / JPG / WebP（cwebp が判別）
#
# Exit codes:
#   0: 成功（最終行にどの手段で変換したかを echo）
#   1: 全変換手段が失敗
#   2: 引数エラー

set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <input> <output.webp> [--lossless | --near-lossless N | --quality N]" >&2
  echo "  default: --quality 95（視覚的にロスレス、ファイル軽量）" >&2
  exit 2
fi

INPUT="$1"
OUTPUT="$2"
shift 2

if [ ! -f "$INPUT" ]; then
  echo "Error: input not found: $INPUT" >&2
  exit 2
fi

# モード判定
MODE="quality"
LEVEL=95

while [ $# -gt 0 ]; do
  case "$1" in
    --lossless)
      MODE="lossless"
      shift
      ;;
    --near-lossless)
      MODE="near-lossless"
      LEVEL="${2:-60}"
      shift 2
      ;;
    --quality)
      MODE="quality"
      LEVEL="${2:-95}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

# cwebp 用引数を配列で構築
case "$MODE" in
  lossless)      CWEBP_ARGS=(-lossless) ;;
  near-lossless) CWEBP_ARGS=(-near_lossless "$LEVEL") ;;
  quality)       CWEBP_ARGS=(-q "$LEVEL") ;;
esac

# === 1st choice: cwebp（全モード対応） ===
if command -v cwebp >/dev/null 2>&1; then
  if cwebp "${CWEBP_ARGS[@]}" "$INPUT" -o "$OUTPUT" >/dev/null 2>&1; then
    echo "ok: cwebp ($MODE${LEVEL:+ $LEVEL})"
    exit 0
  fi
fi

# === 2nd choice: sips（ロッシーのみ） ===
# sips は lossless / near-lossless を持たないので、近い quality 値で代替
if [ "$MODE" = "quality" ]; then
  SIPS_Q="$LEVEL"
else
  SIPS_Q=95  # lossless 系の代替として高品質を使う
fi

if command -v sips >/dev/null 2>&1; then
  if sips -s format webp -s formatOptions "$SIPS_Q" "$INPUT" --out "$OUTPUT" >/dev/null 2>&1; then
    echo "ok: sips (quality $SIPS_Q, $MODE 相当)"
    exit 0
  fi
fi

# === 3rd choice: pngquant（PNG 出力にフォールバック） ===
if command -v pngquant >/dev/null 2>&1; then
  PNG_OUT="${OUTPUT%.webp}.png"
  if pngquant --quality 85-100 --output "$PNG_OUT" "$INPUT" 2>/dev/null; then
    echo "ok: pngquant -> PNG: $PNG_OUT (WebP 不可、PNG で圧縮)"
    exit 0
  fi
fi

echo "Error: 全ての変換手段で失敗（cwebp / sips / pngquant いずれも未インストールまたはエラー）" >&2
echo "Hint: brew install webp" >&2
exit 1
