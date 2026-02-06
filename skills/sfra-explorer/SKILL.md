---
name: sfra-explorer
description: SFRA codebase exploration skill. Phase 1 generates a static Resolution Map (require/superModule/route/template/hook resolution). Phase 2 provides interactive Q&A using the map. Triggers on "SFRA explore", "resolution map", "SFRA 探索"
version: 1.0.0
triggers:
  - "SFRA explore"
  - "SFRA explorer"
  - "resolution map"
  - "SFRA 探索"
  - "解決マップ"
---

# SFRA Explorer スキル

SFRA コードベースの動的モジュール解決を静的に可視化し、AI によるインタラクティブ探索を可能にする。

## 概要

| 項目 | 内容 |
|------|------|
| **対象** | SFRA Storefront（app_storefront_base + overlay / plugin / integration cartridges） |
| **目的** | `require('*/...')`、`module.superModule`、`server.extend/append/prepend/replace`、Hook、テンプレートの解決先を静的に計算し、マップ化 |
| **出力形式** | Markdown 解決マップ（YAML frontmatter + 9 セクション） |
| **中間成果物** | `docs/explore/.work/` に保存 |
| **最終成果物** | `docs/explore/sfra-resolution-map.md` |

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                    Orchestrator (SKILL.md)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 0: Scope Detection (inline)                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ - Cartridge ディレクトリ検出                                 ││
│  │ - Cartridge path 順序決定                                    ││
│  │ - Confidence レベル付与 (high/medium/low)                    ││
│  └─────────────────────────────────────────────────────────────┘│
│                           │                                     │
│  Phase 1: Resolution Map Generation                             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                                                              ││
│  │  Step 1: scanner (sonnet) ← ファイルインベントリ + 正規化JSON ││
│  │                │                                             ││
│  │                ▼                                             ││
│  │  Step 2: ┌──────────┬──────────┐ ← 並列実行                 ││
│  │          │ resolver │  mapper  │                             ││
│  │          │  (opus)  │ (sonnet) │                             ││
│  │          └────┬─────┴────┬─────┘                            ││
│  │               └──────────┘                                   ││
│  │                    │                                         ││
│  │                    ▼                                         ││
│  │  Step 3: assembler (opus) → sfra-resolution-map.md          ││
│  │                                                              ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Phase 2: Interactive Explorer (on-demand)                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ navigator (sonnet) ← 解決マップ + 実コード参照               ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## ワークフロー

### Phase 0: スコープ検出（Orchestrator 内で実行）

**目的**: レビュー対象のカートリッジ構成と順序を特定

**手順**:
1. プロジェクトルートでカートリッジディレクトリを検出

```bash
# Glob パターン
cartridges/*/cartridge/
```

2. カートリッジパスを優先順位に従って決定

| 優先度 | ソース | Confidence |
|--------|--------|------------|
| 1 | ユーザー入力（スキル呼び出し時に指定） | high |
| 2 | `dw.json` の cartridge path 設定 | high |
| 3 | `.project` Eclipse プロジェクト設定 | medium |
| 4 | `package.json` の dependencies から推測 | medium |
| 5 | ディレクトリ構造のみ（アルファベット順） | low |

3. 検出結果をログ出力

```yaml
scope:
  cartridge_path: "app_custom:plugin_wishlists:app_storefront_base"
  cartridge_path_source: "dw.json"
  cartridge_path_confidence: "high"
  cartridges:
    - name: "app_custom"
      type: "overlay"
      path: "cartridges/app_custom"
    - name: "plugin_wishlists"
      type: "plugin"
      path: "cartridges/plugin_wishlists"
    - name: "app_storefront_base"
      type: "base"
      path: "cartridges/app_storefront_base"
  stats:
    total_files: 245
    controllers: 35
    models: 28
    templates: 120
```

**Done 条件**: カートリッジパスが決定し、少なくとも 1 つのカートリッジが検出されている

**Confidence が low の場合**: ユーザーにカートリッジパスの確認を求める。ユーザーが指定すれば confidence を high に格上げ。

---

### Phase 1: 解決マップ生成

**目的**: カートリッジパスに基づく静的解決マップを自動生成

#### Step 1: Scanner（ファイルインベントリ）

**入力**: Phase 0 のスコープ情報（カートリッジパス、ディレクトリ一覧）

```
Task(
  description: "Scan SFRA codebase",
  prompt: "以下のカートリッジパスに従い、コードベースをスキャンしてください。

カートリッジパス: {cartridge_path}
カートリッジディレクトリ:
{cartridge_directories}

Phase 0 で検出された情報:
  - cartridge_path_source: {source}
  - cartridge_path_confidence: {confidence}
  - git_commit: {git_commit}

出力先: docs/explore/.work/01_scan.md

スキャン対象:
1. 全カートリッジのファイルインベントリ
2. require() パターン分類（wildcard/tilde/relative/dw_api/explicit）
3. module.superModule 使用箇所
4. server メソッド（get/post/use/append/prepend/replace/extend）
5. イベントリスナー（this.on('route:*')）
6. イベント発火（this.emit）
7. Hook 登録（package.json hooks → hooks.json）
8. 各ファイルの行数

scanner.md の手順に従って実行してください。",
  subagent_type: "sfra-explorer-scanner",
  model: "sonnet"
)
```

**出力**: `docs/explore/.work/01_scan.md`

**Done 条件**: scanner がハンドオフ封筒 `status: ok` を返却

---

#### Step 2: Resolver + Mapper（並列実行）

scanner の出力が完了したら、resolver と mapper を**単一メッセージ内で並列起動**する。

```
┌─────────────────────────────────────────────────────────────────┐
│ 並列実行（単一メッセージで複数 Task tool 呼び出し）              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Task(sfra-explorer-resolver, model: opus)    ──┐                │
│ Task(sfra-explorer-mapper, model: sonnet)    ──┘─→ 並列         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

##### Resolver

```
Task(
  description: "Resolve SFRA require/superModule",
  prompt: "scanner の出力（docs/explore/.work/01_scan.md）を読み込み、
           以下を計算してください:

1. require('*/...') の解決先（カートリッジパス順で最初のマッチ）
2. module.superModule チェーンの完全トレース（再帰的）
3. ファイル衝突検出（同一相対パスが複数カートリッジに存在）
4. 逆引き依存インデックス
5. 未解決パターン（動的 require 等）

出力先: docs/explore/.work/02_resolution.md

resolver.md の手順に従って実行してください。",
  subagent_type: "sfra-explorer-resolver",
  model: "opus"
)
```

**出力**: `docs/explore/.work/02_resolution.md`

##### Mapper

```
Task(
  description: "Map SFRA routes/templates/hooks",
  prompt: "scanner の出力（docs/explore/.work/01_scan.md）を読み込み、
           以下をマッピングしてください:

1. Controller Route Map（prepend→base→append 実行順序）
2. Template Override Map（ISML テンプレートの解決先）
3. Hook Registration Map（全カートリッジの Hook 登録）

重要: Hook は全カートリッジの登録分が全て実行されます。

出力先: docs/explore/.work/03_map.md

mapper.md の手順に従って実行してください。",
  subagent_type: "sfra-explorer-mapper",
  model: "sonnet"
)
```

**出力**: `docs/explore/.work/03_map.md`

**Done 条件**: resolver と mapper の両方が `status: ok` を返却

---

#### Step 3: Assembler（統合 + 検証）

resolver と mapper の出力が揃ったら、assembler を起動する。

```
Task(
  description: "Assemble SFRA resolution map",
  prompt: "以下の 3 ファイルを読み込み、最終解決マップを生成してください:

1. docs/explore/.work/01_scan.md（scanner 出力）
2. docs/explore/.work/02_resolution.md（resolver 出力）
3. docs/explore/.work/03_map.md（mapper 出力）

テンプレート: templates/resolution-map-template.md

手順:
1. テンプレートのプレースホルダーを実データで置換
2. クロスバリデーション（ファイル数、チェーン数、ルート数、Hook数）
3. 統計計算（Section 9）
4. 最終 Markdown 生成

出力先:
  - docs/explore/sfra-resolution-map.md（最終成果物）
  - docs/explore/.work/04_assembly.md（アセンブリレポート）

assembler.md の手順に従って実行してください。",
  subagent_type: "sfra-explorer-assembler",
  model: "opus"
)
```

**出力**:
- `docs/explore/sfra-resolution-map.md`（最終成果物）
- `docs/explore/.work/04_assembly.md`（アセンブリレポート）

**Done 条件**: assembler が `status: ok` を返却し、`sfra-resolution-map.md` が生成されている

---

### Phase 2: インタラクティブ探索（オンデマンド）

**目的**: 生成された解決マップを参照しながら、ユーザーの質問にインタラクティブに回答

**前提条件**: `docs/explore/sfra-resolution-map.md` が存在すること

```
Task(
  description: "Navigate SFRA resolution map",
  prompt: "解決マップ（docs/explore/sfra-resolution-map.md）を読み込み、
           ユーザーの質問に回答してください。

質問: {user_question}

navigator.md の手順に従い、以下の流れで回答:
1. 解決マップの鮮度チェック（git commit 比較）
2. 質問をカテゴリに分類
3. 該当セクションを参照
4. 必要に応じて実コードを Read で確認
5. 構造化回答を生成

回答には必ずファイルパス:行番号を含めてください。",
  subagent_type: "sfra-explorer-navigator",
  model: "sonnet"
)
```

**対応カテゴリ**:

| カテゴリ | 質問例 | 参照セクション |
|---------|--------|---------------|
| Route Tracing | 「Cart-AddProduct の実行フローは？」 | Section 4 |
| Override Analysis | 「Product.js はどこで上書き？」 | Section 2 |
| Chain Tracing | 「productModel の superModule チェーンは？」 | Section 3 |
| Impact Analysis | 「Cart.js を変更すると影響は？」 | Section 7 |
| Hook Investigation | 「dw.order.calculate の全 Hook は？」 | Section 6 |
| Template Tracing | 「cart.isml の include ツリーは？」 | Section 5 |
| Dependency Mapping | 「app_custom の依存関係は？」 | Section 9 |

**プロンプトカタログ**: 詳細なプロンプトテンプレートは `references/exploration_prompts.md` を参照

---

## エージェント一覧

| Agent | Model | 担当範囲 | 入力 | 出力 |
|-------|-------|---------|------|------|
| scanner | sonnet | ファイルインベントリ、正規化 JSON | カートリッジパス | `.work/01_scan.md` |
| resolver | opus | require 解決、superModule チェーン | scanner 出力 | `.work/02_resolution.md` |
| mapper | sonnet | Route / Template / Hook マッピング | scanner 出力 | `.work/03_map.md` |
| assembler | opus | 統合、クロスバリデーション | scanner + resolver + mapper | `sfra-resolution-map.md` |
| navigator | sonnet | インタラクティブ探索 | 解決マップ + 実コード | 構造化回答 |

## ツール使用ルール

### 各 Phase で使用可能なツール

| Phase | 許可ツール | 備考 |
|-------|-----------|------|
| Phase 0 | Glob, Bash (read-only), Read | スコープ検出のみ |
| Phase 1 Step 1 (scanner) | Read, Glob, Grep, Write | スキャン + `.work/` 出力 |
| Phase 1 Step 2 (resolver) | Read, Glob, Grep, Write | 解決計算 + `.work/` 出力 |
| Phase 1 Step 2 (mapper) | Read, Glob, Grep, Write | マッピング + `.work/` 出力 |
| Phase 1 Step 3 (assembler) | Read, Glob, Write | 統合 + 最終マップ書き込み |
| Phase 2 (navigator) | Read, Glob, Grep | 探索のみ |

### 書き込み制限

- **書き込み可能**: `docs/explore/` および `docs/explore/.work/` のみ
- **読み取り専用**: その他すべてのディレクトリ

---

## 実行フロー

### 自動実行モード（Phase 1）

```
/sfra-explore → Phase 0 → scanner → [resolver + mapper 並列] → assembler → 完了
```

### インタラクティブモード（Phase 2）

```
/sfra-explore で質問 → navigator → 構造化回答
```

### 初回実行判定

1. `docs/explore/sfra-resolution-map.md` が存在するか確認
2. 存在しない場合 → Phase 1 を自動実行
3. 存在する場合 → Phase 2 で質問に回答
4. ユーザーが「再生成」を指示 → Phase 1 を再実行

### 鮮度チェック

解決マップの `git_commit` と現在の HEAD を比較:
- **一致**: マップは最新、Phase 2 で続行
- **不一致**: 「マップが古い可能性があります。再生成しますか？」と確認

---

## Done 判定

| Phase | Done 条件 |
|-------|----------|
| 0 | カートリッジパスが決定し、1 つ以上のカートリッジが検出 |
| 1 Step 1 | `01_scan.md` が生成済み、scanner が `status: ok` |
| 1 Step 2 | `02_resolution.md` + `03_map.md` が生成済み、両方 `status: ok` |
| 1 Step 3 | `sfra-resolution-map.md` が生成済み、assembler が `status: ok` |
| 2 | ユーザーの質問に構造化回答が完了 |

---

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| カートリッジ未検出 | `status: blocked`、ユーザーにパス確認を求める |
| カートリッジパス confidence: low | ユーザーに確認を求める（指定があれば high に格上げ） |
| scanner 失敗 | 原因を報告、Phase 1 からリトライ |
| resolver 失敗 / mapper 成功 | mapper 出力のみで assembler 実行（resolver セクション空欄 + 警告） |
| mapper 失敗 / resolver 成功 | resolver 出力のみで assembler 実行（mapper セクション空欄 + 警告） |
| assembler 失敗 | Step 3 からリトライ |
| 解決マップ未生成で Phase 2 要求 | Phase 1 の実行を推奨 |
| 解決マップが古い | 鮮度警告を表示し、再生成を提案 |

---

## 出力ディレクトリ構造

```
docs/explore/
├── .work/                              # 中間成果物（.gitignore 推奨）
│   ├── 01_scan.md                     # scanner: ファイルインベントリ + 正規化 JSON
│   ├── 02_resolution.md               # resolver: 解決先、チェーン、逆引き
│   ├── 03_map.md                      # mapper: ルート、テンプレート、Hook
│   └── 04_assembly.md                 # assembler: クロスバリデーションレポート
└── sfra-resolution-map.md             # 最終成果物
```

---

## 共有リファレンス

### sfra-explorer 固有

| ファイル | 用途 |
|---------|------|
| `references/sfra_resolution_guide.md` | SFRA 解決メカニズム全解説 + AI 誤解集 |
| `references/resolution_map_schema.md` | 解決マップのスキーマ定義 |
| `references/exploration_prompts.md` | AI 探索プロンプトカタログ |
| `templates/resolution-map-template.md` | 出力テンプレート |

### sfra-review から共有参照（読み取りのみ）

| ファイル | 用途 |
|---------|------|
| `skills/sfra-review/references/sfra_best_practices.md` | Controller/Model/ISML/Service のコード例集 |
| `skills/sfra-review/references/antipatterns.md` | アンチパターンカタログ |
| `skills/sfra-review/references/handoff_schema.md` | ハンドオフ封筒形式 |

**参照方向**: `sfra-explorer → sfra-review/references/`（一方向、読み取りのみ）

---

## sfra-review との連携

sfra-review が解決マップを活用したい場合:

1. ユーザーが先に `/sfra-explore` を実行
2. 生成された `docs/explore/sfra-resolution-map.md` を sfra-review の indexer が検出
3. 解決マップがあればインデックス精度が向上（補完目的、スキップではない）

---

## Notes

- 解決マップには生成メタデータ（`generated_at`, `git_commit`, `cartridge_path_confidence`）が含まれる
- `cartridge_path_source` が `user_input` の場合は confidence が自動的に `high`
- Hook は全カートリッジの登録分が**全て実行される**（`require('*/...')` の「最初のマッチのみ」とは異なる）
- `modules/` フォルダはカートリッジフォルダの**ピア**（同階層）に配置される
