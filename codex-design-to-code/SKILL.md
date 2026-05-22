---
name: codex-design-to-code
description: AIによるデザイン + AIによる実装で、LP / ランディングページ / ダッシュボード / 画面UI / システム画面を **HTML/CSS の動くWebページ** として構築するスキル。Codex CLI (image 2.0 / gpt-image-2) が全画面デザインカンプ → 分割アセットの順に画像を並列生成し、Claude Code がそれを HTML/CSS で実装する2フェーズ設計。最終成果物はカンプと寸分違わぬ実Webページ。トリガー: 「LP作って」「ランディングページ」「デザインカンプ」「画面デザイン」「システムデザイン」「ダッシュボード作って」「UI画面」「mockup」「design comp」「サイト作って」「codexでLP」、または LP/画面ページの新規構築を要求された時。会話を1枚画像にまとめたい用途は別スキル codex-infographic-gen を使う。単発の画像素材だけ欲しい時は本スキルの「カンプなしモード」で対応可。
---

# Codex Design-to-Code（デザイン → コード、2フェーズで実装まで）

LP・ダッシュボード・画面UI を **HTML/CSS の動くWebページ** として作るスキル。Codex CLI に image 2.0 / gpt-image-2 でデザインカンプとアセット画像を作らせ、Claude Code が HTML/CSS で実装する分業設計。

**動作ロジックは `scripts/` に集約されており、SKILL.md は意思決定（プロンプト設計・カンプ承認・インベントリ・実装方針）に集中する。**

## 役割分担 — 厳守

- **Codex**: 画像生成のみ。HTML/CSS は書かせない
- **Claude Code**: orchestration、ファイル配置、HTML/CSS/JS、コピー、プロジェクト雛形、レンダリング画像のレビュー、再生成判断

この分離が肝。Codex は遅い画像作業を並列で fan-out、Claude Code は決定的なビルドを進める。

## Workflow order — ALWAYS comp first, then assets

LP・ダッシュボード・アプリ画面など、どの画面/ページ設計タスクでも:

1. **Phase 1 — 全画面 1 枚カンプを先に生成**。これがビジュアル仕様の出発点
2. **ユーザーにカンプを見せて承認**。「この方向で OK？」と聞いて軌道修正の機会を与える
3. **Phase 2 — 承認後、分割アセットを並列生成**。カンプを参照画像として渡す
4. **HTML/CSS で組み立て**。生成アセットを `<img>` で読み込んでカンプを再現

**「分割アセットだけ作って」と言われても Phase 1 を絶対スキップしない**。カンプがビジュアルの錨で、これが無いと分割アセットの一貫性が崩れる。カンプ自体がユーザーがレビューできる成果物にもなる。

### Design authority — defer to Codex

視覚判断（レイアウト、配色、タイポグラフィの雰囲気、構図、イラストスタイル）は **Codex の提案を尊重する**。カンププロンプトで過剰指定しない。

- **悪い**: "magenta-to-purple gradient, three floating cards at angles X/Y/Z, Orbitron headline left-aligned, ¥1,200 CTA button bottom-right..."
- **良い**: "Full LP comp for an online oripa service for Japanese gacha audience. Sections: hero with hook + CTA, then 2-pack lineup. Mood: premium, exciting, a bit luxurious. Propose layout, palette, typography hierarchy, illustration style."

カンプが出てきたら Read して「Codex が提案したのはこんな感じ」とユーザーに説明、承認を得てから次へ。

## スクリプト一覧（動作ロジック）

| スクリプト | 役割 |
|---|---|
| `scripts/generate_comp.sh` | **Phase 1** — 全画面カンプを1枚生成 |
| `scripts/generate_asset.sh` | **Phase 2** — 単一アセット生成（カンプを参照）。並列実行は Claude が複数回呼ぶ |
| `scripts/run_codex.sh` | codex 起動ラッパー（exit 144 対策込み） |
| `scripts/wait_for_png.sh` | PNG 出現待ち（タイムアウト + サイズ検証） |
各スクリプトは独立して呼べる。挙動を変えたい時は SKILL.md ではなく該当スクリプトを編集する。

**外部依存**: WebP 変換は別スキル **`image-compress`** に委譲（`~/.claude/skills/image-compress/scripts/compress.sh` を直接呼び出す）。同 monorepo 内なのでまとめて配布される。

---

## Phase 1 — Design comp（必須、常に最初）

### 手順

1. **ブリーフを集める**: 目的、ターゲット、セクション構成、ムードキーワード。過剰指定しない
2. **`scripts/generate_comp.sh` をバックグラウンド起動**
3. **生成中に他の作業を進める**: HTML 構造の素案、コピー、セクション設計など
4. **完了したら Read して内容を確認**、ユーザーに「Codex が提案したのは○○調、配色は△△」と要約
5. **ユーザー承認待ち**。必要なら調整プロンプトで再生成

### サイズの目安

- LP（縦長マルチセクション）: 1024x2048 や 1024x2560
- 単画面の UI（ダッシュボード等）: 1536x1024 / 1024x1024

### プロンプトテンプレート（`{{PNG_PATH}}` プレースホルダー必須）

```
以下のフル画面デザインカンプを image 2.0 (gpt-image-2) で生成し、
{{PNG_PATH}} に保存してください。

# 目的
<このページが達成したいこと>

# 対象オーディエンス
<>

# 必須セクション
<hero / 機能紹介 / 料金 / FAQ / CTA など、構成だけ書く>

# ムード・キーワード
<premium / friendly / techy / luxurious 等>

# 制約
- サイズ: <1024x2048 など>
- レイアウト・配色・タイポ・イラストスタイルは codex が判断
- フル画面 1 枚 PNG として、上から下まで全体を描く

完了したら絶対パスと「===CODEX_DONE===」を出力してください。
```

### 実行

```bash
bash /Users/admin/.claude/skills/codex-design-to-code/scripts/generate_comp.sh \
  <slug> /tmp/codex-prompt-comp-<slug>.txt
```

- 必ず `run_in_background: true` で起動
- 完了時の task-notification を受け取ったら、出力末尾の PNG パスを使って Read

---

## Phase 2 — Split assets（カンプ承認後）

**Phase 2 の鉄則**: カンプは仕様、インスピレーションではない。**Replicate, don't reinterpret.**

### 手順

#### 1. INVENTORY（必須）

カンプ PNG を carefully Read して、**目に見える視覚要素を1個1個列挙する**。フラットなチェックリストにする:

- セクションごとの背景
- 主役ビジュアル（hero composition, product shots）
- 装飾オーナメント（フレーム、コーナーfilig ree、区切り、シンボル、透かし）
- ブランドマーク・ロゴ・印章
- 各アイコン1個1個（trust badge、機能アイコン、SNSアイコンなど、行ごとに1個）
- ボタン・バッジ・リボンで「イラスト処理」されているもの（フラットCSSではないもの）
- セクション区切り線、ゴールドライン、装飾divider

各行に: 目標ファイル名、サイズ、透過/不透過、簡潔な説明

#### 2. INVENTORY をユーザーに見せて承認を得る

これは「あとで黙って簡略化しました」を防ぐためのチェックポイント。**生成前に必ずユーザー承認**。

#### 3. 各アセットを並列生成

承認された項目すべてを `generate_asset.sh` で生成。**Claude が同時に複数の Bash 呼び出しを発行**（各 `run_in_background: true`）して並列化する。

```bash
# Bash 呼び出しその1（run_in_background: true）
bash /Users/admin/.claude/skills/codex-design-to-code/scripts/generate_asset.sh \
  lp-oripa hero-bg /tmp/codex-prompt-hero-bg.txt /tmp/comp-lp-oripa.png /path/to/project/public/images

# Bash 呼び出しその2（run_in_background: true、同じ応答で発行）
bash /Users/admin/.claude/skills/codex-design-to-code/scripts/generate_asset.sh \
  lp-oripa icon-truck /tmp/codex-prompt-icon-truck.txt /tmp/comp-lp-oripa.png /path/to/project/public/images

# ...必要な数だけ
```

各 generate_asset.sh は:
1. `/tmp/<slug>-<asset-name>.png` に codex 出力（サンドボックス制約回避）
2. `{{PNG_PATH}}` と `{{COMP_PATH}}` をプロンプト内で置換
3. PNG 完成後、`final-dir/<asset-name>.png` に cp（指定があれば）

#### 4. 画像生成と並行して HTML/CSS を組む

```
カンプを観察してレイアウト測定 → div 構造を書く → 生成された PNG を <img> で読み込む
```

- カンプの実レイアウト（位置・比率・余白・装飾密度）を測って組む。**自分の構図を入れない**
- カンプに読めるコピーがあれば **verbatim で転記**。書き換えない
- カンプで描かれた要素を **絵文字・ASCII グリフ・Unicode・純CSS形状で代替しない**。インベントリに入れて生成する
- CSS で純粋に描いていいのはレイアウトプリミティブのみ（コンテナ、基本ボーダー、ベタ塗り）

#### 5. ファイナルパス: カンプと並べて差分チェック

レンダリングしたページをカンプの隣に開いて比較。drift（アイコンの絵柄、装飾密度、レイアウト比率の違い）があれば部分再生成または CSS 修正。**黙って劣化版を出荷しない** — 簡略化したらユーザーに surface する。

### Phase 2 用プロンプトテンプレート（`{{PNG_PATH}}` と `{{COMP_PATH}}` 必須）

```
参照画像: {{COMP_PATH}} をまず読み込み、このカンプの配色・装飾モチーフ・
スタイルに完全に整合する素材として、以下を生成してください。

# 生成するアセット
<例: hero-bg ヒーローセクションの背景。中央に光、左上から右下にかけて
       淡いグラデーション、カンプ上部のセクションと同じ色味>

# サイズ
<例: 1920x1080、透過なし>

# 用途
<例: HTML <img> でヒーローのフルブリードに使う>

# 制約
- カンプの一部要素として違和感なく嵌まること
- カンプの色・装飾密度・スタイルから逸脱しない

保存先: {{PNG_PATH}}

完了したら絶対パスと「===CODEX_DONE===」を出力してください。
```

## Anti-shortcut rules (enforced)

以下をやりたくなったら **STOP**。アセットを生成するか、ユーザーに確認するか:

- "アイコンに 🚚 / ★ / ✓ / 絵文字を使う" — **NO**。カンプの各アイコンを生成
- "ブランドマークを CSS テキストで書く" — **NO**。カンプに描かれてるなら生成
- "装飾フレームを単純な border で省略" — **NO**。フレームを生成 or 省略を surface
- "ヘッドラインをきれいに書き直す" — **NO**。カンプのコピーを verbatim
- "ヒーローの構図を better balance に再アレンジ" — **NO**。カンプの構図に揃える
- "だいたい合ってるからシップ" — **NO**。カンプと diff、drift を flag

これらのショートカットは productive に感じるが、ユーザーが承認したものとは違うビルドになる。**カンプ = 合意**。

## When asset mode without a comp is OK

カンプなしで単発アセットだけ作っていいのは:

- 1〜2 個のスタンドアロン素材（hero image 1個、OGP、アイコンセット）で
- 周辺の画面/ページ構成が無い場合のみ

スクリーン/ページ構成を伴うなら、必ずカンプから。

## File path conventions

- **プロジェクトアセット**: `<project>/public/images/` or `<project>/assets/`
- **単発生成（プロジェクト未確定）**: `~/Downloads/` — スマホ転送・SNS共有が楽
- **中間・スクラッチ**: `/tmp/codex-img-<slug>-<n>.png`、`/tmp/<slug>-<asset-name>.png`（generate_asset.sh の中間）
- **拡張子**: `.png` を生成、Web 配信時に `.webp` へ変換
- **ファイル名**: `comp-<page>.png`, `hero-<slug>.png`, `icon-<name>.png`, `section-<n>-<topic>.png`

### 保存先の決め方

1. ユーザーが明示パス指定 → そのパス
2. プロジェクトディレクトリ内（`public/images/` などが既に存在）→ プロジェクト配下
3. それ以外 → `~/Downloads/`

**最終成果物として `/tmp/` に置きっぱなしにしない**（ユーザーが見つけられない、再起動で消える）。

## WebP optimization（Web 配信時）

Web 配信用に PNG を WebP 変換すると 1/5〜1/8 に圧縮できる。**image-compress スキル**に委譲する:

```bash
bash ~/.claude/skills/image-compress/scripts/compress.sh \
  input.png output.webp
```

- デフォルト quality 95（視覚的にロスレス、ファイル軽量）
- `--lossless` / `--near-lossless N` / `--quality N` でモード切替可能
- 内部: cwebp → sips → pngquant の3段フォールバック
- 透過必須の UI 素材は PNG のまま運用（互換性で迷ったら PNG のまま）

詳細は image-compress スキルの SKILL.md 参照。

## Prompting Codex for image 2.0

ビジュアルプロンプトの構造:

```
[Subject/Scene] / [Style or medium] / [Lighting] / [Color palette] /
[Composition + aspect framing] / [Mood] / [Quality modifiers]
```

Tips:

- **aspect ratio と用途を明示**（例: "designed as full-bleed LP hero, 16:9, copy space on the left third"）
- **画像内テキスト焼き込みは避ける** — image 2.0 でも日本語は不安定（漢字崩れ・欠字・誤字）。重要コピーは HTML/CSS でオーバーレイ。どうしても焼き込みなら 2-4 文字の短ラベル・英数字優先
- **会話の1枚インフォグラフィック用途**は本スキルではなく `codex-infographic-gen` を使う
- UI/システムカンプ: "flat UI mockup, screenshot of a {SaaS dashboard / mobile app screen}, no device frame, sharp pixel-aligned edges, Inter/Noto Sans typography (rendered as shapes)"
- LP イラスト: "editorial illustration, consistent character set, transparent background where possible"
- 日本人オーディエンス: "for Japanese audience" を明示してスタイル・文化キューを合わせる

## 失敗ハンドリング

scripts/generate_comp.sh / generate_asset.sh は明確な exit code を返す:

| exit code | 意味 | 対応 |
|---|---|---|
| 0 | 成功 | stdout 最終行のパスを使って次へ |
| 1 | PNG 生成タイムアウト or サイズ異常 | stdout に Codex log の tail。ユーザーに要約・再試行確認 |
| 2 | 引数エラー | slug / prompt / comp-path の指定を確認 |
| 3 | cp 失敗（generate_asset.sh のみ）| final-dir の存在・権限を確認 |

その他:

- **Sandbox write blocked**: codex に `/tmp/` 保存を指示しているので通常発生しない。発生時は cwd への保存に切り替え
- **Network access denied** や他サンドボックスエラー: `--sandbox` を外す or `OPENAI_API_KEY` を確認
- **Codex がモデル名を hallucinate**: 安全なデフォルトは `gpt-image-2`（一般）/ `gpt-image-1.5`（true transparent PNG が必要な時）
- **Race condition on cp**: generate_asset.sh は codex プロセス完全終了を `wait` してから cp するので発生しないはず
- **codex コマンドが見つからない**: `npm install -g @openai/codex` を案内

## やらないこと（スキルの境界）

- 会話を1枚画像にまとめる → `codex-infographic-gen` の領域
- Codex に HTML/CSS を書かせる → Claude 側の仕事
- カンプ Phase をスキップ → 不一致の原因、絶対やらない
- Anti-shortcut の各項目を「省略 OK」で済ます → 合意違反

これらに踏み込みそうになったら、いったん止めてユーザーに確認する。
