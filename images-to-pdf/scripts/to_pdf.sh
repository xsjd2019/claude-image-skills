#!/bin/bash
# Usage: to_pdf.sh <input1> <input2> ... -o <output.pdf> [options]
#
# 複数の画像を1つの PDF にまとめる。
# A4 portrait、24pt 余白、中央配置、contain（no upscale）が既定。
# pdf-lib ベースの Web 実装と同じレイアウト思想（A4 portrait, 24pt 余白, 中央配置, no upscale）。
#
# 入力形式:
#   PNG / JPEG / TIFF: img2pdf が直接埋め込み（再エンコードなし、品質保持）
#   WebP / GIF / その他: sips で PNG に変換してから埋め込み
#
# Options:
#   -o, --output PATH      出力 PDF のパス（必須）
#   --pagesize SIZE        A4 | Letter | <W>x<H>（既定: A4）
#   --margin PT            余白 pt（既定: 24）
#   --orientation MODE     portrait | landscape（既定: portrait）
#
# 初回実行時、img2pdf が未インストールなら brew で自動インストール。
#
# Exit codes:
#   0: 成功
#   1: PDF 生成失敗
#   2: 引数エラー
#   3: 依存ツール（brew / img2pdf）が無く自動インストール失敗

set -e

show_usage() {
  echo "Usage: $0 <input1> <input2> ... -o <output.pdf> [options]" >&2
  echo "  -o, --output PATH      出力 PDF パス（必須）" >&2
  echo "  --pagesize SIZE        A4 | Letter | <W>x<H>（既定: A4）" >&2
  echo "  --margin PT            余白 pt（既定: 24）" >&2
  echo "  --orientation MODE     portrait | landscape（既定: portrait）" >&2
}

# ----- 引数パース -----
INPUTS=()
OUTPUT=""
PAGESIZE="A4"
MARGIN=24
ORIENTATION="portrait"

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output)    OUTPUT="$2"; shift 2 ;;
    --pagesize)     PAGESIZE="$2"; shift 2 ;;
    --margin)       MARGIN="$2"; shift 2 ;;
    --orientation)  ORIENTATION="$2"; shift 2 ;;
    -h|--help)      show_usage; exit 0 ;;
    -*)             echo "Unknown option: $1" >&2; show_usage; exit 2 ;;
    *)              INPUTS+=("$1"); shift ;;
  esac
done

if [ ${#INPUTS[@]} -eq 0 ] || [ -z "$OUTPUT" ]; then
  show_usage
  exit 2
fi

# ----- img2pdf 自動インストール -----
if ! command -v img2pdf >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "→ 初回実行: img2pdf を brew で自動インストール中..." >&2
    if ! brew install img2pdf >&2; then
      echo "失敗。手動で: brew install img2pdf" >&2
      exit 3
    fi
  else
    echo "Error: img2pdf が無く、Homebrew も見つからない" >&2
    echo "Homebrew をインストール: https://brew.sh/" >&2
    echo "その後、自動的にimg2pdfが入ります" >&2
    exit 3
  fi
fi

# ----- 入力の前処理（img2pdf 非対応形式は sips で PNG 変換） -----
PROCESSED=()
TEMP_FILES=()
cleanup() {
  for t in "${TEMP_FILES[@]}"; do rm -f "$t" 2>/dev/null; done
}
trap cleanup EXIT

for p in "${INPUTS[@]}"; do
  if [ ! -f "$p" ]; then
    echo "Error: 入力ファイルが見つからない: $p" >&2
    exit 2
  fi
  ext_lower=$(echo "${p##*.}" | tr '[:upper:]' '[:lower:]')
  case "$ext_lower" in
    jpg|jpeg|png|tif|tiff)
      PROCESSED+=("$p")
      ;;
    *)
      # img2pdf 非対応 → sips で PNG 化
      TMP="/tmp/_topdf_$$_${#PROCESSED[@]}.png"
      if ! sips -s format png "$p" --out "$TMP" >/dev/null 2>&1; then
        echo "Error: 形式変換失敗 ($ext_lower → png): $p" >&2
        exit 1
      fi
      PROCESSED+=("$TMP")
      TEMP_FILES+=("$TMP")
      ;;
  esac
done

# ----- ページサイズ（landscape は ^T で transpose） -----
PAGESIZE_ARG="$PAGESIZE"
if [ "$ORIENTATION" = "landscape" ]; then
  PAGESIZE_ARG="${PAGESIZE}^T"
fi

# ----- 出力ディレクトリ作成（必要なら） -----
OUT_DIR="$(dirname "$OUTPUT")"
[ -d "$OUT_DIR" ] || mkdir -p "$OUT_DIR"

# ----- img2pdf 実行 -----
if ! img2pdf \
  "${PROCESSED[@]}" \
  --pagesize "$PAGESIZE_ARG" \
  --border "${MARGIN}pt:${MARGIN}pt" \
  --fit into \
  -o "$OUTPUT" 2>&1; then
  echo "Error: PDF 生成失敗" >&2
  exit 1
fi

# ----- 結果 -----
SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
echo "ok: $OUTPUT (${#INPUTS[@]} pages, $SIZE)"
