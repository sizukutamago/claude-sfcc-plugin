# SFRA Explorer

SFRA コードベースの動的モジュール解決を静的に可視化し、AI によるインタラクティブ探索を可能にするスキル。

## 解決する課題

SFRA の以下のパターンは AI がコードを正確にトレースする際の障壁となる:

- `require('*/cartridge/...')` — カートリッジパス順で最初のマッチを返す動的解決
- `module.superModule` — 次のカートリッジの同名モジュールを返す継承チェーン
- `server.append/prepend/replace/extend` — コントローラーミドルウェアチェーン
- `this.on('route:BeforeComplete')` — EventEmitter ベースのルートライフサイクル
- Hook — 全カートリッジの登録分が全て実行される拡張ポイント
- ISML `isinclude` — カートリッジパス順で解決されるテンプレート参照

このスキルは、これらの解決先を事前に計算し、9 セクションの **Resolution Map** として Markdown 出力する。

## 使い方

### Phase 1: 解決マップ生成

```
/sfra-explore
```

初回実行時、以下のパイプラインが自動実行される:

```
scanner → [resolver + mapper 並列] → assembler → sfra-resolution-map.md
```

### Phase 2: インタラクティブ探索

解決マップ生成後、質問形式で探索:

```
/sfra-explore Cart-AddProduct の実行フローは？
/sfra-explore Product.js はどこで上書きされている？
/sfra-explore app_custom の依存関係を見せて
```

### 対応する質問カテゴリ

| カテゴリ | 質問例 |
|---------|--------|
| Route Tracing | 「Cart-AddProduct の実行フローは？」 |
| Override Analysis | 「Product.js はどこで上書きされている？」 |
| Chain Tracing | 「productModel の superModule チェーンは？」 |
| Impact Analysis | 「Cart.js を変更すると影響範囲は？」 |
| Hook Investigation | 「dw.order.calculate の全 Hook は？」 |
| Template Tracing | 「cart.isml の include ツリーは？」 |
| Dependency Mapping | 「app_custom の依存関係は？」 |

## 出力

### 最終成果物

`docs/explore/sfra-resolution-map.md` — 9 セクションの解決マップ:

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

解決マップには以下のメタデータが YAML frontmatter として含まれる:

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

1. 先に `/sfra-explore` で解決マップを生成
2. sfra-review の indexer が解決マップを検出し、分析精度が向上
3. 参照方向は一方向（sfra-explorer → sfra-review は読み取り参照のみ）

## アーキテクチャ

```
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
  navigator (sonnet) ← インタラクティブ探索（on-demand）
```

## トラブルシューティング

| 状況 | 対処 |
|------|------|
| 「カートリッジが検出されません」 | プロジェクトルートに `cartridges/*/cartridge/` 構造があるか確認。なければカートリッジパスを明示的に指定 |
| confidence が `low` と表示される | `dw.json` または `.project` ファイルが見つからない状態。カートリッジパスを手動で指定すると `high` に格上げ |
| 解決マップが古い（git commit 不一致） | `/sfra-explore` を再実行して再生成。コード変更後は毎回再生成を推奨 |
| resolver または mapper が失敗 | 成功した分だけで解決マップが生成される（該当セクション空欄 + 警告付き）。原因を確認して再実行 |
| Phase 2 で「マップがありません」 | 先に Phase 1（解決マップ生成）を実行する必要がある |

### 再生成の判断基準

以下の変更後は解決マップの再生成を推奨:
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
- `references/resolution_map_schema.md` — 解決マップのスキーマ定義
- `references/exploration_prompts.md` — AI 探索プロンプトカタログ
- `templates/resolution-map-template.md` — 出力テンプレート
