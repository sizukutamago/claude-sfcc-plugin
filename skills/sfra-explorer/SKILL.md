---
name: sfra-explorer
description: Interactive SFRA codebase investigation and exploration skill. Supports direct code investigation (route tracing, override analysis, business logic, data flow, hook investigation) with or without a pre-generated Resolution Map. Triggers on "SFRA explore", "SFRA investigate", "SFRA 探索", "SFRA 調査", "コード調査", "コード探索"
version: 2.0.0
triggers:
  - "SFRA explore"
  - "SFRA explorer"
  - "SFRA investigate"
  - "SFRA 探索"
  - "SFRA 調査"
  - "コード調査"
  - "コード探索"
---

# SFRA Explorer スキル

SFRA コードベースのインタラクティブ調査・探索を支援するスキル。コードフロー追跡、モジュール関係分析、ビジネスロジック調査に対応する。

## 概要

| 項目 | 内容 |
|------|------|
| **対象** | SFRA Storefront（app_storefront_base + overlay / plugin / integration cartridges） |
| **目的** | SFRA コードベースを調査・探索し、ルート実行フロー、モジュール解決、ビジネスロジック、データフロー等をトレースして回答する |
| **2モード** | Mode A: 直接調査（即座に探索）/ Mode B: Knowledge Base 生成 + 調査 |

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
│  Mode A: Direct Investigation（Resolution Map 不要）             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ investigator (sonnet) ← Glob/Grep/Read で直接探索            ││
│  │ Resolution Map があれば参照して高速化                         ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Mode B: Knowledge Base 生成 + 調査（大規模・反復調査向け）       │
│  ┌─────────────────────────────────────────────────────────────┐│
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
│  │                    │                                         ││
│  │                    ▼                                         ││
│  │  investigator (sonnet) ← Map 参照 + 実コード確認             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 実行フロー判定

ユーザーの入力に基づき、以下のロジックでモードを決定する:

| 優先度 | 条件 | 実行モード |
|--------|------|-----------|
| 1 | ユーザーが「マップ生成」「全体分析」「Knowledge Base」を明示的に要求 | Mode B |
| 2 | 質問・調査系の入力 + Resolution Map 存在 | Mode A（Map 参照付き） |
| 3 | 質問・調査系の入力 + Resolution Map なし | Mode A（直接探索） |
| 4 | 初回実行で質問なし | Phase 0 でスコープ検出 → ユーザーに質問を求める |
| 5 | 曖昧な入力（「調査して、あとマップも」等） | まず Mode A で即答、その後「Map も生成しますか？」と確認して Mode B を提案 |

**判定キーワード**:
- Mode B トリガー: 「マップ生成」「全体分析」「全体をスキャン」「Knowledge Base」「generate map」「full analysis」
- Mode A トリガー: 質問文（「〜は？」「〜を教えて」「〜のフローは？」等）、調査系キーワード

---

## 対応カテゴリ

| カテゴリ | 説明 | Resolution Map 依存 |
|---------|------|-------------------|
| Route Tracing | ルート実行フロー + ミドルウェアチェーン追跡 | 不要（あれば高速化） |
| Override Analysis | ファイル上書き関係 | 不要（あれば高速化） |
| Chain Tracing | superModule 継承チェーン追跡 | 不要（あれば高速化） |
| Impact Analysis | 変更影響範囲 | あれば精度向上 |
| Hook Investigation | Hook 調査（全カートリッジ実行の注意含む） | 不要（あれば高速化） |
| Template Tracing | テンプレート追跡 | 不要（あれば高速化） |
| Dependency Mapping | 依存関係可視化 | あれば精度向上 |
| Business Logic | ビジネスロジック調査（価格計算、在庫等） | 不要 |
| Data Flow | pdict ライフサイクル、Model→Controller→ISML のデータ追跡 | 不要 |
| Code Pattern | パターン横断検索（Transaction.wrap、Service 呼出し等） | 不要 |

---

## ワークフロー

### Phase 0: スコープ検出（Orchestrator 内で実行）

**目的**: 調査対象のカートリッジ構成と順序を特定

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

### Mode A: Direct Investigation（investigator による直接調査）

**目的**: Resolution Map の有無を問わず、ユーザーの質問に即座に回答

```
Task(
  description: "Investigate SFRA codebase",
  prompt: "ユーザーの質問に回答してください。

質問: {user_question}

カートリッジパス: {cartridge_path}
カートリッジディレクトリ:
{cartridge_directories}

Resolution Map: {map_status}
（存在する場合: docs/explore/sfra-resolution-map.md を参照可能）

investigator.md の手順に従い、以下の流れで回答:
1. Resolution Map の存在確認（なくても続行）
2. Map があれば読み込み + 鮮度チェック
3. 質問をカテゴリに分類
4. Map データ or 直接探索で情報収集
5. 構造化回答を生成

回答には必ずファイルパス:行番号を含めてください。",
  subagent_type: "sfra-explorer-investigator",
  model: "sonnet"
)
```

**対応カテゴリ**: 上記 10 カテゴリ全て

---

### Mode B: Knowledge Base 生成 + 調査

**目的**: 大規模プロジェクトの反復調査向けに、事前分析した Resolution Map を生成

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
2. docs/explore/.work/02_resolution.md（resolver 出力、欠損の場合あり）
3. docs/explore/.work/03_map.md（mapper 出力、欠損の場合あり）

テンプレート: templates/resolution-map-template.md

手順:
1. 存在するファイルのみ読み込む（resolver or mapper が失敗した場合、欠損ファイルはスキップ）
2. テンプレートのプレースホルダーを実データで置換（欠損セクションは空欄 + 警告付き）
3. クロスバリデーション（ファイル数、チェーン数、ルート数、Hook数）
4. 統計計算（Section 9）
5. 最終 Markdown 生成

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

#### Mode B 完了後

Resolution Map 生成が完了したら、ユーザーの質問があれば Mode A の investigator を起動して回答する。investigator は生成された Map を参照して高速に回答する。

---

## エージェント一覧

| Agent | Model | 担当範囲 | 入力 | 出力 |
|-------|-------|---------|------|------|
| investigator | sonnet | インタラクティブ調査（全 10 カテゴリ） | 質問 + 実コード（+ Map） | 構造化回答 |
| scanner | sonnet | ファイルインベントリ、正規化 JSON | カートリッジパス | `.work/01_scan.md` |
| resolver | opus | require 解決、superModule チェーン | scanner 出力 | `.work/02_resolution.md` |
| mapper | sonnet | Route / Template / Hook マッピング | scanner 出力 | `.work/03_map.md` |
| assembler | opus | 統合、クロスバリデーション | scanner + resolver + mapper | `sfra-resolution-map.md` |

## ツール使用ルール

### 各モード / Phase で使用可能なツール

| Phase / Mode | 許可ツール | 備考 |
|-------------|-----------|------|
| Phase 0 | Glob, Bash (read-only), Read | スコープ検出のみ |
| Mode A (investigator) | Read, Glob, Grep | 調査のみ（読み取り専用） |
| Mode B Step 1 (scanner) | Read, Glob, Grep, Write | スキャン + `.work/` 出力 |
| Mode B Step 2 (resolver) | Read, Glob, Grep, Write | 解決計算 + `.work/` 出力 |
| Mode B Step 2 (mapper) | Read, Glob, Grep, Write | マッピング + `.work/` 出力 |
| Mode B Step 3 (assembler) | Read, Glob, Write | 統合 + 最終マップ書き込み |

### 書き込み制限

- **書き込み可能**: `docs/explore/` および `docs/explore/.work/` のみ
- **読み取り専用**: その他すべてのディレクトリ

---

## 実行フロー

### Mode A: 直接調査（デフォルト）

```
/sfra-explore {質問} → Phase 0 → investigator → 構造化回答
```

### Mode B: Knowledge Base 生成

```
/sfra-explore（マップ生成指示） → Phase 0 → scanner → [resolver + mapper 並列] → assembler → 完了
```

### Mode A with Map: Map 参照付き調査

```
/sfra-explore {質問}（Map 存在時） → investigator（Map 参照 + 実コード確認） → 構造化回答
```

### 初回実行判定

1. ユーザーが質問を含めている → Mode A（Map 有無に関わらず即座に調査開始）
2. ユーザーが「マップ生成」を指示 → Mode B
3. 質問なし・指示なし → Phase 0 でスコープ検出 → ユーザーに質問を求める

### 鮮度チェック

Resolution Map が存在する場合、`git_commit` と現在の HEAD を比較:
- **一致**: マップは最新、investigator が Map を参照
- **不一致**: investigator が鮮度警告を表示して続行（Map のデータは参考として使用）

---

## Done 判定

| Phase / Mode | Done 条件 |
|-------------|----------|
| Phase 0 | カートリッジパスが決定し、1 つ以上のカートリッジが検出 |
| Mode A | ユーザーの質問に構造化回答が完了 |
| Mode B Step 1 | `01_scan.md` が生成済み、scanner が `status: ok` |
| Mode B Step 2 | `02_resolution.md` + `03_map.md` が生成済み、両方 `status: ok` |
| Mode B Step 3 | `sfra-resolution-map.md` が生成済み、assembler が `status: ok` |

---

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| カートリッジ未検出 | `status: blocked`、ユーザーにパス確認を求める |
| カートリッジパス confidence: low | ユーザーに確認を求める（指定があれば high に格上げ） |
| scanner 失敗 | 原因を報告、Mode B からリトライ |
| resolver 失敗 / mapper 成功 | mapper 出力のみで assembler 実行（resolver セクション空欄 + 警告） |
| mapper 失敗 / resolver 成功 | resolver 出力のみで assembler 実行（mapper セクション空欄 + 警告） |
| assembler 失敗 | Step 3 からリトライ |
| Resolution Map なしで質問 | **Mode A で直接探索**（blocked にしない） |
| Resolution Map が古い | 鮮度警告を表示して続行、再生成は提案のみ |

---

## 出力ディレクトリ構造

```
docs/explore/
├── .work/                              # 中間成果物（.gitignore 推奨）
│   ├── 01_scan.md                     # scanner: ファイルインベントリ + 正規化 JSON
│   ├── 02_resolution.md               # resolver: 解決先、チェーン、逆引き
│   ├── 03_map.md                      # mapper: ルート、テンプレート、Hook
│   └── 04_assembly.md                 # assembler: クロスバリデーションレポート
└── sfra-resolution-map.md             # Resolution Map（Mode B で生成）
```

---

## 共有リファレンス

### sfra-explorer 固有

| ファイル | 用途 |
|---------|------|
| `references/sfra_resolution_guide.md` | SFRA 解決メカニズム全解説 + AI 誤解集 |
| `references/resolution_map_schema.md` | Resolution Map のスキーマ定義 |
| `references/exploration_prompts.md` | AI 探索プロンプトカタログ |
| `templates/resolution-map-template.md` | 出力テンプレート（Mode B 用） |

### sfra-review から共有参照（読み取りのみ）

| ファイル | 用途 |
|---------|------|
| `skills/sfra-review/references/sfra_best_practices.md` | Controller/Model/ISML/Service のコード例集 |
| `skills/sfra-review/references/antipatterns.md` | アンチパターンカタログ |
| `skills/sfra-review/references/handoff_schema.md` | ハンドオフ封筒形式 |

**参照方向**: `sfra-explorer → sfra-review/references/`（一方向、読み取りのみ）

---

## sfra-review との連携

sfra-review が Resolution Map を活用したい場合:

1. ユーザーが先に `/sfra-explore`（Mode B）を実行
2. 生成された `docs/explore/sfra-resolution-map.md` を sfra-review の indexer が検出
3. Resolution Map があればインデックス精度が向上（補完目的、スキップではない）

---

## Notes

- Resolution Map には生成メタデータ（`generated_at`, `git_commit`, `cartridge_path_confidence`）が含まれる
- `cartridge_path_source` が `user_input` の場合は confidence が自動的に `high`
- Hook は全カートリッジの登録分が**全て実行される**（`require('*/...')` の「最初のマッチのみ」とは異なる）
- `modules/` フォルダはカートリッジフォルダの**ピア**（同階層）に配置される
- investigator は sonnet を使用（コスト/レイテンシのバランス。orchestrator 判断で複雑な質問には opus 指定も可能）
