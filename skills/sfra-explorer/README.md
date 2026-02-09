# SFRA Explorer

SFRA コードベースのインタラクティブ調査・探索を支援するスキル。コードフロー追跡、モジュール関係分析、ビジネスロジック調査に対応する。

## 解決する課題

SFRA の以下のパターンは AI がコードを正確にトレースする際の障壁となる:

- `require('*/cartridge/...')` — カートリッジパス順で最初のマッチを返す動的解決
- `module.superModule` — 次のカートリッジの同名モジュールを返す継承チェーン
- `server.append/prepend/replace/extend` — コントローラーミドルウェアチェーン
- `this.on('route:BeforeComplete')` — EventEmitter ベースのルートライフサイクル
- Hook — 全カートリッジの登録分が全て実行される拡張ポイント
- ISML `isinclude` — カートリッジパス順で解決されるテンプレート参照

このスキルは、これらの SFRA 固有パターンを理解した上でコードを調査・探索し、ユーザーの質問に回答する。大規模プロジェクトでは事前分析した Resolution Map を生成して高速化することもできる。

## 使い方

### Mode A: 直接調査（デフォルト）

質問形式で即座に調査を開始:

```
/sfra-explore Cart-AddProduct の実行フローは？
/sfra-explore Product.js はどこで上書きされている？
/sfra-explore 商品価格はどこで計算される？
/sfra-explore Transaction.wrap を使っている全箇所は？
```

Resolution Map がなくても直接コードを探索して回答する。Map が存在すれば参照して高速化する。

### Mode B: Knowledge Base 生成（大規模・反復調査向け）

```
/sfra-explore（マップ生成を指示）
```

以下のパイプラインで Resolution Map を事前生成:

```
scanner → [resolver + mapper 並列] → assembler → sfra-resolution-map.md
```

### 対応する質問カテゴリ

| カテゴリ | 質問例 | Map 依存 |
|---------|--------|---------|
| Route Tracing | 「Cart-AddProduct の実行フローは？」 | 不要 |
| Override Analysis | 「Product.js はどこで上書きされている？」 | 不要 |
| Chain Tracing | 「productModel の superModule チェーンは？」 | 不要 |
| Impact Analysis | 「Cart.js を変更すると影響範囲は？」 | あれば精度向上 |
| Hook Investigation | 「dw.order.calculate の全 Hook は？」 | 不要 |
| Template Tracing | 「cart.isml の include ツリーは？」 | 不要 |
| Dependency Mapping | 「app_custom の依存関係は？」 | あれば精度向上 |
| Business Logic | 「商品価格はどこで計算される？」 | 不要 |
| Data Flow | 「product.availability の流れは？」 | 不要 |
| Code Pattern | 「Transaction.wrap の全使用箇所は？」 | 不要 |

## 出力

### Resolution Map（Mode B で生成）

`docs/explore/sfra-resolution-map.md` — 9 セクションの Resolution Map:

| Section | 内容 |
|---------|------|
| 1. Cartridge Stack | カートリッジの優先順位と構成 |
| 2. File Resolution Table | 各ファイルの解決先マッピング |
| 3. SuperModule Chains | 継承チェーンの可視化 |
| 4. Controller Route Map | ルート実行順序とイベントリスナー |
| 5. Template Override Map | テンプレートの上書き関係 |
| 6. Hook Registration Map | Hook 登録と実行順序 |
| 7. Reverse Dependency Index | 逆引き依存インデックス |
| 8. Unresolved / Dynamic | 静的解析で解決できないパターン |
| 9. Dependency Graph Summary | カートリッジ間依存関係 + 統計 |

### メタデータ

Resolution Map には以下のメタデータが YAML frontmatter として含まれる:

```yaml
generated_at: "2026-02-06T12:00:00Z"
git_commit: "abc1234"
cartridge_path_source: "dw.json"
cartridge_path_confidence: "high"
cartridge_path: "app_custom:plugin_wishlists:app_storefront_base"
```

## カートリッジパスの決定

以下の優先順位でカートリッジパスを自動検出:

1. **ユーザー指定** — スキル呼び出し時に明示的に指定（confidence: high）
2. **dw.json** — Business Manager 設定ファイル（confidence: high）
3. **.project** — Eclipse プロジェクト設定（confidence: medium）
4. **package.json** — 依存関係から推測（confidence: medium）
5. **ディレクトリ構造** — フォールバック（confidence: low）

## sfra-review との連携

sfra-review スキルと連携して使用可能:

1. 先に `/sfra-explore`（Mode B）で Resolution Map を生成
2. sfra-review の indexer が Resolution Map を検出し、分析精度が向上
3. 参照方向は一方向（sfra-explorer → sfra-review は読み取り参照のみ）

## アーキテクチャ

```
Mode A: Direct Investigation
  investigator (sonnet) ← Glob/Grep/Read で直接探索 + Map 参照（任意）

Mode B: Knowledge Base 生成
  scanner (sonnet)     ← ファイルインベントリ + 正規化 JSON
       │
       ▼
  ┌──────────┬──────────┐
  │ resolver │  mapper  │  ← 並列実行
  │  (opus)  │ (sonnet) │
  └────┬─────┴────┬─────┘
       └──────────┘
            │
            ▼
    assembler (opus)   → sfra-resolution-map.md
            │
            ▼
    investigator (sonnet) ← Map 参照 + 実コード確認
```

## トラブルシューティング

| 状況 | 対処 |
|------|------|
| 「カートリッジが検出されません」 | プロジェクトルートに `cartridges/*/cartridge/` 構造があるか確認。なければカートリッジパスを明示的に指定 |
| confidence が `low` と表示される | `dw.json` または `.project` ファイルが見つからない状態。カートリッジパスを手動で指定すると `high` に格上げ |
| Resolution Map が古い（git commit 不一致） | investigator が鮮度警告を表示して続行。精度が気になる場合は Mode B で再生成 |
| resolver または mapper が失敗 | 成功した分だけで Resolution Map が生成される（該当セクション空欄 + 警告付き）。原因を確認して再実行 |

### 再生成の判断基準

以下の変更後は Resolution Map の再生成を推奨:
- カートリッジの追加・削除
- カートリッジパスの順序変更
- コントローラーやモデルの追加・削除
- `package.json` の hooks エントリ変更

### confidence が low の場合の入力例

```
/sfra-explore cartridge_path=app_custom:plugin_wishlists:app_storefront_base
```

## リファレンス

- `references/sfra_resolution_guide.md` — SFRA 解決メカニズム全解説 + AI 誤解集
- `references/resolution_map_schema.md` — Resolution Map のスキーマ定義
- `references/exploration_prompts.md` — AI 探索プロンプトカタログ
- `templates/resolution-map-template.md` — 出力テンプレート（Mode B 用）
