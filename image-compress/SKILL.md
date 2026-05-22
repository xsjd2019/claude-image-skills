---
name: image-compress
description: 画像（PNG / JPG / WebP）を**品質を落とさず WebP に圧縮**するスキル。デフォルトは quality 95 で「視覚的に劣化なし」+「ファイル軽量」のバランス点。トリガー: 「画像圧縮」「画像を軽量化」「webp化」「WebPに変換」「圧縮して」「compress image」「webp化して」、または他スキル（codex-infographic-gen など）から WebP 出力を生成する時。他スキルから `bash ~/.claude/skills/image-compress/scripts/compress.sh <input> <output>` で直接呼び出し可能。cwebp / sips / pngquant の3段フォールバックで環境差にも強い。
---

# Image Compress（画像を品質落とさず WebP に圧縮）

画像（PNG / JPG / WebP 等）を WebP に変換しつつファイルサイズを削減する。**品質劣化が視覚的にわからない** ことを最優先する設計。

## 圧縮モード

| モード | 引数 | 用途 |
|---|---|---|
| **quality 95（既定）** | `--quality <N>` / 既定 | 視覚的にロスレス + ファイル軽量。テキスト・グラフィックス中心の画像で最適 |
| **lossless** | `--lossless` | 完全可逆圧縮。1bit たりとも変えたくない場合。ファイルは最大になる |
| **near-lossless** | `--near-lossless <N>` | アルゴリズム的に near-lossless。写真でアーティファクト最小化したい時。テキスト中心の画像では quality 95 より大きくなる傾向 |

引数なしで呼ぶと **quality 95** で実行される。

### 選び方

- 普通のインフォグラフィック / スクショ / UIキャプチャ → 既定（quality 95）でOK
- 写真でアーティファクトに敏感 → `--near-lossless 60`
- 厳密なピクセル保存が必要（再編集用、印刷入稿） → `--lossless`

## 使い方

### コマンドラインから

```bash
# 既定（quality 95、視覚的にロスレス）
bash ~/.claude/skills/image-compress/scripts/compress.sh input.png output.webp

# 完全可逆
bash ~/.claude/skills/image-compress/scripts/compress.sh input.png output.webp --lossless

# 近ロスレス（写真向き）
bash ~/.claude/skills/image-compress/scripts/compress.sh photo.jpg out.webp --near-lossless 60

# より小さくしたい時
bash ~/.claude/skills/image-compress/scripts/compress.sh input.png output.webp --quality 85
```

### 他スキルから呼び出す

このスキルの `scripts/compress.sh` は**他スキルから直接 bash で叩ける**ように設計されている:

```bash
# 例: codex-infographic-gen が generate.sh の中で呼ぶ
bash ~/.claude/skills/image-compress/scripts/compress.sh \
  /tmp/infographic-xxx.png \
  ~/Downloads/infographic-xxx.webp
```

呼び出し側は image-compress スキルを Skill ツール経由で発火させる必要はない。スクリプトのフルパスを直接実行すれば OK。

## 圧縮ロジック（3段フォールバック）

| 順位 | ツール | 対応モード | インストール |
|---|---|---|---|
| 1 | `cwebp` | 全モード対応、最安定 | `brew install webp` |
| 2 | `sips` | quality のみ（lossless 系は q95 で代替） | macOS 標準 |
| 3 | `pngquant` | WebP 不可（**.png 出力にフォールバック**） | `brew install pngquant` |

cwebp が入っていれば常にそれが使われる。無い環境でも sips/pngquant に自動フォールバック。

## ファイルサイズの目安

1024x1536 のインフォグラフィック（PNG 約 1.3MB、テキスト・図形メイン）を圧縮した実測値:

| モード | ファイルサイズ | 品質 |
|---|---|---|
| `--quality 85` | 〜130KB | 軽い圧縮アーティファクト（文字エッジに微差） |
| **`--quality 95`（既定）** | **〜213KB** | 視覚的にロスレス |
| `--near-lossless 60` | 〜691KB | アルゴリズム的に near-lossless（テキスト中心では quality 95 より大きい） |
| `--lossless` | 〜860KB | 完全可逆 |

テキスト・グラフィックス中心の画像では **quality 95 が最小 + 視覚的にロスレス** の最適点。near-lossless は写真でアーティファクトに敏感な時に使う。

写真は変動が大きい。`--quality 95` から始めて、容量問題なら下げる、品質問題なら `--near-lossless` か `--lossless` へ。

## トリガー条件（このスキルがいつ発火するか）

ユーザーの発話に以下があれば発火:

- 「画像圧縮して」「画像軽くして」「画像軽量化」
- 「webp化して」「WebP に変換」
- 「圧縮 + WebP」
- 単発の画像最適化要求全般

他スキルから内部呼び出しされる時は **Skill ツール経由ではなく**、`scripts/compress.sh` を直接 bash する。

## 出力ファイルの場所

呼び出し側が `<output>` で指定したパスにそのまま出力する。スキル自体は保存先のポリシーを持たない（呼び出し側で `~/Downloads/`, プロジェクトの `assets/`, `/tmp/` などを決める）。

## 失敗ハンドリング

| exit code | 意味 | 対応 |
|---|---|---|
| 0 | 成功 | stdout に使用ツール名（cwebp / sips / pngquant）が出る |
| 1 | 全変換手段で失敗 | `brew install webp` を案内 |
| 2 | 引数エラー | usage を確認 |

## やらないこと（スキルの境界）

- 画像の生成・編集・トリミング → 別スキルへ
- バッチ処理（ディレクトリ一括圧縮） → 呼び出し側でループ
- 形式変換以外の加工（リサイズ・色調補正など） → 別ツールで先に処理
