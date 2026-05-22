#!/bin/bash
# Usage: resize.sh <input> <output> <mode> [args]
#
# モード（いずれか1つ必須）:
#   --scale <pct>          : pct%でリサイズ。例: --scale 50%, --scale 25, --scale 75%
#   --width <N>            : 幅をNにし、高さはアスペクト維持
#   --height <N>           : 高さをNにし、幅はアスペクト維持
#   --max-dimension <N>    : 長辺をN以下にし、アスペクト維持
#   --template <name>      : プリセット適用（下記参照）
#
# テンプレ（--template の引数）:
#   # SNS / Web
#   ogp                 1200 x 630   (Open Graph Protocol)
#   twitter-card        1200 x 675
#   youtube-thumb       1280 x 720
#   instagram-square    1080 x 1080
#   instagram-story     1080 x 1920
#   blog-hero           1920 x 600
#
#   # アイコン（単一サイズ）
#   favicon             32 x 32
#   favicon-large       192 x 192
#   apple-touch-icon    180 x 180
#   iphone-icon         1024 x 1024  (App Store 提出用)
#   android-icon        512 x 512    (Play Store 提出用)
#   pwa-icon            512 x 512
#
# テンプレ使用時のクロップ:
#   デフォルトは cover（短辺基準で拡大→中央クロップ）。--fit contain でレターボックス。
#
# 出力形式: 入力の拡張子を維持（sips が判別）。フォーマット変換は別スキル（image-compress）へ。
#
# Exit codes:
#   0: 成功
#   1: sips エラー
#   2: 引数エラー

set -e

show_usage() {
  echo "Usage: $0 <input> <output> [--scale N% | --width N | --height N | --max-dimension N | --template <name>] [--fit cover|contain]" >&2
  echo "" >&2
  echo "Templates: ogp, twitter-card, youtube-thumb, instagram-square, instagram-story, blog-hero," >&2
  echo "           favicon, favicon-large, apple-touch-icon, iphone-icon, android-icon, pwa-icon" >&2
}

if [ $# -lt 3 ]; then
  show_usage
  exit 2
fi

INPUT="$1"
OUTPUT="$2"
shift 2

if [ ! -f "$INPUT" ]; then
  echo "Error: input not found: $INPUT" >&2
  exit 2
fi

MODE=""
VALUE=""
TEMPLATE=""
FIT="cover"

while [ $# -gt 0 ]; do
  case "$1" in
    --scale)          MODE="scale"; VALUE="$2"; shift 2 ;;
    --width)          MODE="width"; VALUE="$2"; shift 2 ;;
    --height)         MODE="height"; VALUE="$2"; shift 2 ;;
    --max-dimension)  MODE="max"; VALUE="$2"; shift 2 ;;
    --template)       MODE="template"; TEMPLATE="$2"; shift 2 ;;
    --fit)            FIT="$2"; shift 2 ;;
    *)                echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Error: mode required" >&2
  show_usage
  exit 2
fi

# テンプレ → 寸法
TARGET_W=0
TARGET_H=0
if [ "$MODE" = "template" ]; then
  case "$TEMPLATE" in
    ogp)              TARGET_W=1200; TARGET_H=630 ;;
    twitter-card)     TARGET_W=1200; TARGET_H=675 ;;
    youtube-thumb)    TARGET_W=1280; TARGET_H=720 ;;
    instagram-square) TARGET_W=1080; TARGET_H=1080 ;;
    instagram-story)  TARGET_W=1080; TARGET_H=1920 ;;
    blog-hero)        TARGET_W=1920; TARGET_H=600 ;;
    favicon)          TARGET_W=32;   TARGET_H=32 ;;
    favicon-large)    TARGET_W=192;  TARGET_H=192 ;;
    apple-touch-icon) TARGET_W=180;  TARGET_H=180 ;;
    iphone-icon)      TARGET_W=1024; TARGET_H=1024 ;;
    android-icon)     TARGET_W=512;  TARGET_H=512 ;;
    pwa-icon)         TARGET_W=512;  TARGET_H=512 ;;
    *) echo "Unknown template: $TEMPLATE" >&2; show_usage; exit 2 ;;
  esac
fi

# 入力寸法
SRC_W=$(sips -g pixelWidth "$INPUT" | awk '/pixelWidth/ {print $2}')
SRC_H=$(sips -g pixelHeight "$INPUT" | awk '/pixelHeight/ {print $2}')

case "$MODE" in
  scale)
    PCT="${VALUE%\%}"
    NEW_W=$(awk "BEGIN { print int($SRC_W * $PCT / 100 + 0.5) }")
    NEW_H=$(awk "BEGIN { print int($SRC_H * $PCT / 100 + 0.5) }")
    sips -z "$NEW_H" "$NEW_W" "$INPUT" --out "$OUTPUT" >/dev/null
    echo "ok: ${SRC_W}x${SRC_H} → ${NEW_W}x${NEW_H} (${PCT}%)"
    ;;

  width)
    sips --resampleWidth "$VALUE" "$INPUT" --out "$OUTPUT" >/dev/null
    NEW_W=$(sips -g pixelWidth "$OUTPUT" | awk '/pixelWidth/ {print $2}')
    NEW_H=$(sips -g pixelHeight "$OUTPUT" | awk '/pixelHeight/ {print $2}')
    echo "ok: ${SRC_W}x${SRC_H} → ${NEW_W}x${NEW_H} (width=${VALUE})"
    ;;

  height)
    sips --resampleHeight "$VALUE" "$INPUT" --out "$OUTPUT" >/dev/null
    NEW_W=$(sips -g pixelWidth "$OUTPUT" | awk '/pixelWidth/ {print $2}')
    NEW_H=$(sips -g pixelHeight "$OUTPUT" | awk '/pixelHeight/ {print $2}')
    echo "ok: ${SRC_W}x${SRC_H} → ${NEW_W}x${NEW_H} (height=${VALUE})"
    ;;

  max)
    sips -Z "$VALUE" "$INPUT" --out "$OUTPUT" >/dev/null
    NEW_W=$(sips -g pixelWidth "$OUTPUT" | awk '/pixelWidth/ {print $2}')
    NEW_H=$(sips -g pixelHeight "$OUTPUT" | awk '/pixelHeight/ {print $2}')
    echo "ok: ${SRC_W}x${SRC_H} → ${NEW_W}x${NEW_H} (max-dimension=${VALUE})"
    ;;

  template)
    if [ "$FIT" = "cover" ]; then
      # cover: 短辺を target に合わせ拡大 → 中央クロップ
      # 必要スケール = max(target_w/src_w, target_h/src_h)
      SCALE=$(awk "BEGIN { sw=$TARGET_W/$SRC_W; sh=$TARGET_H/$SRC_H; print (sw > sh ? sw : sh) }")
      INTERIM_W=$(awk "BEGIN { print int($SRC_W * $SCALE + 0.5) }")
      INTERIM_H=$(awk "BEGIN { print int($SRC_H * $SCALE + 0.5) }")
      # 拡大（中間）
      sips -z "$INTERIM_H" "$INTERIM_W" "$INPUT" --out "$OUTPUT" >/dev/null
      # 中央クロップ
      sips -c "$TARGET_H" "$TARGET_W" "$OUTPUT" >/dev/null
      echo "ok: ${SRC_W}x${SRC_H} → ${TARGET_W}x${TARGET_H} (${TEMPLATE}, cover)"
    elif [ "$FIT" = "contain" ]; then
      # contain: 長辺を target に合わせ縮小、レターボックスなし（実寸はアスペクト維持）
      SCALE=$(awk "BEGIN { sw=$TARGET_W/$SRC_W; sh=$TARGET_H/$SRC_H; print (sw < sh ? sw : sh) }")
      NEW_W=$(awk "BEGIN { print int($SRC_W * $SCALE + 0.5) }")
      NEW_H=$(awk "BEGIN { print int($SRC_H * $SCALE + 0.5) }")
      sips -z "$NEW_H" "$NEW_W" "$INPUT" --out "$OUTPUT" >/dev/null
      echo "ok: ${SRC_W}x${SRC_H} → ${NEW_W}x${NEW_H} (${TEMPLATE}, contain — レターボックスなし)"
    else
      echo "Error: --fit は cover か contain を指定" >&2
      exit 2
    fi
    ;;
esac
