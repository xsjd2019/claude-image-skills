---
name: image-resize
description: 画像をリサイズするスキル。パーセント縮小（25/50/75%等）、手動寸法指定（幅/高さ/長辺）、用途別テンプレート（OGP、Twitter Card、YouTube サムネ、各種アイコン、favicon 等）を1コマンドで実行。トリガー: 「リサイズして」「画像をリサイズ」「サイズ変更」「縮小して」「拡大して」「サムネ作って」「OGPサイズ」「favicon にして」「アイコンサイズに」「半分のサイズ」、または他スキルから画像寸法変更が必要な時。他スキルから `bash ~/.claude/skills/image-resize/scripts/resize.sh <input> <output> <mode>` で直接呼び出し可能。フォーマット変換は image-compress スキルとの連携で行う（resize → compress の順）。
---

# Image Resize（用途別テンプレート + 自由指定）

画像の寸法を変える専用スキル。テンプレート、パーセント、手動寸法の3系統で**1コマンドで完結**する設計。format 変換はスコープ外（image-compress に委譲）。

## モード

### 1. テンプレート（用途別プリセット）

`--template <name>` で1コマンドで仕上げる。

**SNS / Web**

| テンプレ | サイズ | 用途 |
|---|---|---|
| `ogp` | 1200 × 630 | Open Graph Protocol（Facebook、LINE 等） |
| `twitter-card` | 1200 × 675 | Twitter / X Summary Card with Large Image |
| `youtube-thumb` | 1280 × 720 | YouTube サムネイル |
| `instagram-square` | 1080 × 1080 | Instagram フィード（正方形） |
| `instagram-story` | 1080 × 1920 | Instagram ストーリーズ |
| `blog-hero` | 1920 × 600 | ブログのワイドヒーロー |

**アイコン**

| テンプレ | サイズ | 用途 |
|---|---|---|
| `favicon` | 32 × 32 | 標準 favicon |
| `favicon-large` | 192 × 192 | 大きい favicon（Android Chrome） |
| `apple-touch-icon` | 180 × 180 | iOS Safari ホーム画面追加 |
| `iphone-icon` | 1024 × 1024 | iOS App Store 提出用（Xcode が下位サイズを生成） |
| `android-icon` | 512 × 512 | Google Play Store 提出用 |
| `pwa-icon` | 512 × 512 | PWA manifest 用 |

#### テンプレ使用時のクロップ挙動

入力のアスペクト比とテンプレが違うとき:
- `--fit cover`（既定）: 短辺を target に合わせて拡大し、中央でクロップ。**情報の一部が切れる代わりに target の寸法を完全に満たす**
- `--fit contain`: 長辺を target に合わせて縮小。アスペクトは保たれるが寸法は target と一致しない（レターボックス処理はなし）

### 2. パーセント縮小・拡大

`--scale <pct>` で全体倍率を指定:

```bash
--scale 50%     # 半分
--scale 25      # 25% (% 省略可)
--scale 75%
--scale 200     # 倍
```

### 3. 手動寸法

| 引数 | 動作 |
|---|---|
| `--width N` | 幅をNに、高さはアスペクト維持 |
| `--height N` | 高さをNに、幅はアスペクト維持 |
| `--max-dimension N` | 長辺がN以下になるよう縮小（短辺は連動） |

## 使い方

```bash
# テンプレ — OGP
bash ~/.claude/skills/image-resize/scripts/resize.sh \
  in.png out.png --template ogp

# テンプレ — iPhone アイコン
bash ~/.claude/skills/image-resize/scripts/resize.sh \
  logo.png icon-1024.png --template iphone-icon

# 50% に縮小
bash ~/.claude/skills/image-resize/scripts/resize.sh \
  in.png out.png --scale 50%

# 幅 1200 (アスペクト維持)
bash ~/.claude/skills/image-resize/scripts/resize.sh \
  in.png out.png --width 1200

# 長辺 800 以下に
bash ~/.claude/skills/image-resize/scripts/resize.sh \
  in.png out.png --max-dimension 800

# テンプレで contain（クロップなし、レターボックスなし）
bash ~/.claude/skills/image-resize/scripts/resize.sh \
  in.png out.png --template ogp --fit contain
```

## image-compress との組み合わせ（推奨パターン）

リサイズと WebP 化を両方やりたい時は、2スキルを順に呼ぶ:

```bash
# Step 1: リサイズ（OGP サイズへ）
bash ~/.claude/skills/image-resize/scripts/resize.sh \
  source.png /tmp/resized.png --template ogp

# Step 2: 圧縮 + WebP 化
bash ~/.claude/skills/image-compress/scripts/compress.sh \
  /tmp/resized.png ~/Downloads/ogp.webp
```

Claude が「OGP 用に WebP で」のような複合要求を受けた時は、上のチェーンを自動で組む。

## トリガー条件

ユーザーの発話で発火:

- 「リサイズして」「サイズ変更」「縮小して」「拡大して」
- 「半分のサイズに」「50%に」「25% に縮小」
- 「OGPサイズに」「Twitter用に」「YouTube サムネに」
- 「favicon にして」「アイコンサイズに」「iOS アイコンサイズ」
- 「○○ x ○○ にして」「幅 1200 に」「長辺 800 以下に」

他スキルから内部呼び出し時は **Skill ツール経由ではなく bash で直接スクリプトを叩く**。

## 出力フォーマット

入力ファイルの拡張子をそのまま使う（sips が判別して保存）。**フォーマット変換はしない**:
- PNG → PNG
- JPG → JPG
- WebP → WebP

WebP 化が必要なら **image-compress スキル** にチェーンする（上記「組み合わせパターン」参照）。

## 失敗ハンドリング

| exit code | 意味 | 対応 |
|---|---|---|
| 0 | 成功 | stdout に `<旧寸法> → <新寸法>` |
| 1 | sips エラー | 入力ファイル破損 or sips がサポートしない形式の可能性 |
| 2 | 引数エラー | usage を確認 |

## やらないこと（スキルの境界）

- 圧縮 / WebP 変換 → image-compress に委譲
- 複数サイズ一括出力（PWA アイコンセットなど） → 呼び出し側で複数回ループ
- 画像の生成・色調補正・装飾追加 → スコープ外
- 余白追加 / レターボックス処理（contain 時の背景塗り） → ImageMagick が必要、要望あれば追加
