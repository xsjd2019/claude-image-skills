---
name: images-to-pdf
description: 複数の画像を1つの PDF にまとめるスキル。A4 portrait・中央配置・contain（no upscale）・24pt 余白が既定。PNG/JPEG は再エンコードなしで品質保持、WebP/GIF/HEIC など img2pdf 非対応形式は sips で PNG に変換してから埋め込み。トリガー: 「画像をPDFに」「複数画像PDF」「images to pdf」「マニュアル化」「pdf化して」「スクショまとめて」、または複数の画像を1つの文書にまとめたい時。他スキルから `bash ~/.claude/skills/images-to-pdf/scripts/to_pdf.sh <imgs...> -o <pdf>` で直接呼び出し可能。初回実行時に img2pdf を brew で自動インストール。
---

# Images to PDF（複数画像を1つのPDFに）

複数の画像（スクショ、写真、図など）を A4 portrait 1 ページ 1 画像で PDF にまとめる。マニュアル化、スクショ集約、報告書作成などに使う。

ロジックは pdf-lib ベースの Web 実装と同じ思想:
- A4 portrait
- 24pt 余白（4辺）
- 各画像は contain で中央配置（拡大はしない＝ no upscale）
- 1 画像 = 1 ページ

## 仕組み

```
入力画像 ─┐
         ├─→ PNG/JPEG/TIFF → そのまま img2pdf に渡す（品質保持、再エンコードなし）
         └─→ WebP/GIF/HEIC など → sips で PNG 化 → img2pdf へ
                                              ↓
                              A4 ページに contain + 中央配置で配置
                                              ↓
                                          1 つの PDF
```

## 依存

| ツール | 用途 | インストール |
|---|---|---|
| **img2pdf** | PDF 組み立て本体 | brew install img2pdf（**初回実行時に自動**） |
| **sips** | WebP/GIF 等の前処理 | macOS 標準（不要） |
| **brew** | 自動インストールに必要 | 通常 macOS 開発者環境に存在 |

初回実行時に img2pdf が無ければ自動で `brew install img2pdf` が走る。brew も無い環境ではエラー + 案内。

## 使い方

### 基本（A4 portrait、24pt 余白、中央配置）

```bash
bash ~/.claude/skills/images-to-pdf/scripts/to_pdf.sh \
  screenshot1.png screenshot2.png photo.jpg \
  -o ~/Downloads/manual.pdf
```

### オプション

| 引数 | 動作 |
|---|---|
| `-o, --output PATH` | 出力 PDF パス（必須） |
| `--pagesize SIZE` | `A4`（既定） / `Letter` / `<W>x<H>` 任意指定 |
| `--margin PT` | 余白 pt（既定 24） |
| `--orientation MODE` | `portrait`（既定） / `landscape` |

### 例

```bash
# Letter サイズ + 余白 12pt
bash ~/.claude/skills/images-to-pdf/scripts/to_pdf.sh \
  *.png -o out.pdf --pagesize Letter --margin 12

# A4 landscape
bash ~/.claude/skills/images-to-pdf/scripts/to_pdf.sh \
  diagram1.webp diagram2.webp \
  -o out.pdf --orientation landscape

# シェルの glob 展開で「ディレクトリ内の全PNG」をまとめる
bash ~/.claude/skills/images-to-pdf/scripts/to_pdf.sh \
  ~/screenshots/*.png \
  -o ~/Downloads/screenshots.pdf
```

ページの順番は引数の並び順。glob で渡すとアルファベット順（=ファイル名順）になる。

## 他スキルとの連携

### resize → compress → to_pdf

例: スクショを一旦リサイズ・最適化してから PDF にまとめる

```bash
# Step 1: 各画像を最大幅 1024 にリサイズ
for img in shot*.png; do
  bash ~/.claude/skills/image-resize/scripts/resize.sh \
    "$img" "/tmp/r-$img" --max-dimension 1024
done

# Step 2: 全部を PDF にまとめる
bash ~/.claude/skills/images-to-pdf/scripts/to_pdf.sh \
  /tmp/r-*.png -o ~/Downloads/manual.pdf
```

PDF 自体は内部で品質保持のまま埋め込まれるので、サイズを抑えたければ**渡す前**にリサイズする。

## トリガー条件

ユーザーの発話で発火:

- 「画像をPDFにまとめて」「複数画像PDF」
- 「マニュアル化して」「PDF化」「pdf化して」
- 「スクショまとめて PDF に」
- 「images to pdf」「combine images」
- ファイルパスを複数渡して「これを PDF に」

他スキルから内部呼び出し時は **Skill ツール経由ではなく** `bash to_pdf.sh ...` を直接実行。

## 失敗ハンドリング

| exit code | 意味 | 対応 |
|---|---|---|
| 0 | 成功 | stdout に `ok: <path> (N pages, X.XM)` |
| 1 | PDF 生成失敗 | img2pdf のエラーメッセージを確認、入力画像が壊れていないか確認 |
| 2 | 引数エラー | usage 確認、入力ファイル存在確認 |
| 3 | 依存ツール不在 | brew が無い環境では brew インストール後に再実行 |

## ファイルサイズ

各画像が PDF にそのまま埋め込まれるため、出力サイズは**入力画像の合計サイズに比例**。

| 入力 | 出力 PDF |
|---|---|
| PNG（1024x1536, 1.3MB）2 枚 | 約 2.2 MB |
| JPG（写真）5 枚 各 200KB | 約 1.0 MB |
| WebP 経由（sips で PNG 化されるため一時的に肥大）| 元のサイズより大きくなる場合あり |

PDF を軽くしたい場合は、画像を渡す前に [`image-resize`](../image-resize/) でリサイズ、または [`image-compress`](../image-compress/) で WebP 圧縮した PNG を渡すと効果的。

## やらないこと（スキルの境界）

- 1 ページに複数画像を並べる → 1 画像 1 ページ方針
- 画像の編集（トリミング・回転・色調補正）→ 別スキル or 渡す前に処理
- 既存 PDF の結合・分割 → スコープ外
- OCR / テキスト埋め込み → スコープ外
- 透かしやヘッダー/フッター追加 → スコープ外
