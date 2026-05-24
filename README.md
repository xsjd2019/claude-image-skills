# claude-image-skills

Claude Code 用の **画像生成・画像処理スキル集**（monorepo）。

会話の文脈を1枚のインフォグラフィックにする、AI で LP/UI 画面のデザインを生成して HTML/CSS で実装する、画像を WebP に圧縮する、用途別テンプレートでリサイズする、といった画像まわりの作業を Claude Code から1コマンドで叩けるようになる。

## 収録スキル

| スキル | 何をするか |
|---|---|
| [**codex-infographic-gen**](./codex-infographic-gen/) | 会話の文脈を1枚の日本語インフォグラフィック画像（WebP）として生成し、`~/Downloads/` に保存。Codex CLI の image 2.0 (gpt-image-2) で生成。情報量が多ければ複数枚に自動分割 |
| [**codex-design-to-code**](./codex-design-to-code/) | AI デザイン + AI 実装で LP / 画面 UI を HTML/CSS の動く Web ページとして構築。Codex がカンプ → 分割アセットを並列生成し、Claude が HTML/CSS で組み立てる 2 フェーズ設計 |
| [**image-compress**](./image-compress/) | 画像（PNG/JPG/WebP）を**品質を落とさず WebP に圧縮**。`--quality 95` 既定。`--lossless` / `--near-lossless` モード切替対応。cwebp → sips → pngquant の 3 段フォールバック |
| [**image-resize**](./image-resize/) | 画像をリサイズ。`--scale 50%` などのパーセント縮小、`--width/--height/--max-dimension` の手動寸法、`--template ogp / favicon / iphone-icon` 等の用途別テンプレート |
| [**images-to-pdf**](./images-to-pdf/) | 複数画像を 1 つの PDF にまとめる。A4 portrait・中央配置・contain（no upscale）・24pt 余白が既定。マニュアル化、スクショ集約用途。img2pdf を brew で自動インストール |

## 依存関係

```
image-compress（共通ユーティリティ）
   ▲                ▲
   │                │
codex-infographic-gen   codex-design-to-code
                        （WebP 配信時に呼び出し）

image-resize（独立）
```

- **image-compress** は他スキルから `bash ~/.claude/skills/image-compress/scripts/compress.sh ...` で直接呼び出される
- **image-resize** は単体動作、Claude が「リサイズ → 圧縮」のチェーンで他スキルと組み合わせる
- **images-to-pdf** は単体動作、複数画像を A4 PDF にまとめる
- **codex-* 系**は OpenAI Codex CLI に依存（`npm install -g @openai/codex`）

## 動作要件

- macOS（sips、osascript を使用）
- Homebrew で `webp`（`brew install webp`）— cwebp の最も安定したフォールバック
- Homebrew で `img2pdf`（images-to-pdf スキルの初回実行時に自動インストール）
- Node.js 経由で Codex CLI（`npm install -g @openai/codex`）— Codex 系スキルのみ

## インストール

```bash
# 1. 任意の場所に clone
git clone git@github.com:xsjd2019/claude-image-skills.git ~/projects/claude-image-skills

# 2. 各スキルを ~/.claude/skills/ に symlink
for s in codex-infographic-gen codex-design-to-code image-compress image-resize images-to-pdf; do
  ln -s ~/projects/claude-image-skills/$s ~/.claude/skills/$s
done

# 3. Claude Code を再起動
# 自動で各スキルが発火可能になる
```

更新時:
```bash
cd ~/projects/claude-image-skills && git pull
# symlink 経由なので全スキルが同時に最新化される
```

## トリガー例

普段の使い方:

| 発話 | 発火スキル | 期待される動作 |
|---|---|---|
| 「インフォグラフィックにまとめて」 | codex-infographic-gen | 会話文脈 → WebP 1枚を `~/Downloads/` へ |
| 「LP 作って」 | codex-design-to-code | カンプ生成 → 承認 → 分割アセット並列生成 → HTML/CSS 実装 |
| 「圧縮して」「webp化して」 | image-compress | 指定画像を WebP に変換 |
| 「OGP サイズに」「favicon にして」 | image-resize | 指定画像を用途別テンプレートサイズに |
| 「画像をPDFに」「マニュアル化」「スクショまとめて」 | images-to-pdf | 複数画像を A4 PDF に集約 |

詳細は各スキルの `SKILL.md` を参照。

## 設計原則

- **動作ロジックは `scripts/`、意思決定は `SKILL.md`** — SKILL.md は Claude が「何をするか」を判断、scripts は決定論的に動く
- **長プロンプト対策** — codex 系は exit 144 を避けるため、プロンプトをファイル経由 + stdin クローズで渡す
- **ピクセル境界の判断は AI に任せない** — クロップなどは codex に強制せず、出力をそのまま扱う
- **トンマナはプリセット化**（codex-infographic-gen の `references/styles/<name>.md`）— ブランド一貫性を確保しつつ用途別に切替

## ライセンス

MIT License。自由に利用・改変・再配布できます。

```
Copyright (c) 2026 xsjd2019

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
