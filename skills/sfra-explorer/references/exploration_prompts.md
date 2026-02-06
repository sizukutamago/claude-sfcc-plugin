# Exploration Prompts Catalog

AI エージェントが SFRA コードベースを探索する際に使用する、構造化プロンプトのカタログ。
navigator エージェントがインタラクティブ探索（Phase 2）で活用する。

---

## カテゴリ一覧

| カテゴリ | 用途 | 典型的な質問 |
|---------|------|------------|
| [Route Tracing](#route-tracing) | コントローラールートの実行フロー追跡 | 「Cart-AddProduct の処理を追って」 |
| [Override Analysis](#override-analysis) | ファイルの上書き関係の分析 | 「Product.js はどこで上書きされている？」 |
| [Chain Tracing](#chain-tracing) | superModule チェーンの追跡 | 「productModel の継承チェーンを見せて」 |
| [Impact Analysis](#impact-analysis) | 変更の影響範囲分析 | 「Cart.js を変更すると何に影響する？」 |
| [Hook Investigation](#hook-investigation) | Hook の登録と実行の調査 | 「dw.order.calculate の全 Hook を見せて」 |
| [Template Tracing](#template-tracing) | テンプレートの解決と include 追跡 | 「cart.isml の include ツリーを見せて」 |
| [Dependency Mapping](#dependency-mapping) | カートリッジ間の依存関係可視化 | 「app_custom は何に依存している？」 |

---

## Route Tracing

### プロンプト: ルート実行フロー

```
[Route] {Controller}-{Action} の完全な実行フローを表示してください。

解決マップの Section 4 (Controller Route Map) を参照し:
1. prepend → base/replace → append の実行順序
2. 各ステップの定義元カートリッジとファイル:行番号
3. route:BeforeComplete / route:Complete イベントリスナー
4. 各ミドルウェアで設定される ViewData のキー

出力形式:
  1. [prepend] app_custom/controllers/Cart.js:15 — CSRF 検証
  2. [base] app_storefront_base/controllers/Cart.js:42 — カート追加ロジック
  3. [append] plugin_wishlists/controllers/Cart.js:88 — ウィッシュリスト連動
  4. [event:BeforeComplete] app_storefront_base/controllers/Cart.js:85 — DB 書き込み
```

### プロンプト: ルートの全ミドルウェア引数

```
[Route] {Controller}-{Action} で使用されているミドルウェア引数を表示してください。

例:
  server.get('Show',
    server.middleware.https,      ← HTTPS 強制
    server.middleware.include,    ← remote include 対応
    consentTracking.consent,      ← 同意トラッキング
    cache.applyDefaultCache,      ← キャッシュ設定
    function (req, res, next) {   ← メインロジック
```

---

## Override Analysis

### プロンプト: ファイル上書き関係

```
[Override] {ファイルパス} の上書き関係を表示してください。

解決マップの Section 2 (File Resolution Table) を参照し:
1. 実際に解決されるカートリッジ (Resolves From)
2. シャドウイングされるカートリッジ (Also In)
3. module.superModule の解決先
4. 各カートリッジ版の差分サマリー（実コード参照）
```

### プロンプト: カートリッジ間の差分

```
[Diff] {カートリッジA} と {カートリッジB} の {ファイルパス} の違いを要約してください。

比較ポイント:
1. 追加されたメソッド/プロパティ
2. 変更されたロジック
3. 削除された機能
4. superModule の使用有無
```

---

## Chain Tracing

### プロンプト: superModule チェーン

```
[Chain] {ファイル名} の module.superModule 継承チェーンを完全にトレースしてください。

解決マップの Section 3 (SuperModule Chains) を参照し:
1. 完全なチェーン表示: A → B → C → null
2. 各ステップで追加/変更されるフィールド
3. プロトタイプ継承パターンか Mixin パターンか
4. チェーン長が 5 以上の場合は警告

出力形式:
  Chain: app_custom/models/product.js
    → plugin_wishlists/models/product.js (adds: wishlistFlag)
    → app_storefront_base/models/product.js (base: 35 fields)
    → null
  Depth: 3 ✓
```

### プロンプト: 特定メソッドの継承追跡

```
[Method] {クラス名}.{メソッド名} の実装がチェーン内でどう変化するか追跡してください。

各カートリッジでの実装を比較:
1. Base の実装
2. 各オーバーライドでの変更内容
3. base.prototype.{method}.call(this, ...) の有無
4. 最終的な動作
```

---

## Impact Analysis

### プロンプト: 変更影響範囲

```
[Impact] {ファイルパス} を変更した場合の影響範囲を分析してください。

解決マップの Section 7 (Reverse Dependency Index) を参照し:
1. このファイルを require している全ファイル（直接参照）
2. superModule チェーンで依存しているファイル
3. このファイルのルートを append/prepend しているコントローラー
4. このファイルが提供するテンプレートを include しているテンプレート

影響度:
  - 高: 直接 require + superModule 依存
  - 中: テンプレート include / Hook 経由
  - 低: 間接的な依存（2ホップ以上）
```

### プロンプト: 安全な変更戦略

```
[Strategy] {ファイルパス} を安全に変更するための戦略を提案してください。

考慮事項:
1. server.replace vs server.append の選択
2. superModule を使った非破壊的拡張
3. 影響を受けるテンプレートの一覧
4. テストすべきルート一覧
```

---

## Hook Investigation

### プロンプト: Hook 実行マップ

```
[Hook] {フック名} の全登録と実行順序を表示してください。

解決マップの Section 6 (Hook Registration Map) を参照し:
1. 登録している全カートリッジ（全て実行される）
2. 各カートリッジの実行スクリプトパス
3. カートリッジパス順の実行順序
4. 各 Hook 実装の処理概要

重要: Hook は require('*/...') と異なり、全カートリッジの登録分が全て実行されます。
```

### プロンプト: Hook 競合分析

```
[Hook Conflict] {フック名} で複数カートリッジの Hook 間に競合がないか分析してください。

チェック項目:
1. 同じデータを異なる方法で変更していないか
2. 実行順序に依存するロジックがないか
3. 片方の Hook が他方の前提条件を壊していないか
```

---

## Template Tracing

### プロンプト: テンプレート解決と include ツリー

```
[Template] {テンプレートパス} の解決先と include ツリーを表示してください。

解決マップの Section 5 (Template Override Map) を参照し:
1. 実際にレンダリングされるカートリッジ (Provided By)
2. 上書きされるカートリッジ (Overrides)
3. isinclude で参照される全テンプレート（再帰的）
4. ロケール別テンプレートの存在確認

出力形式:
  cart/cart.isml (app_custom, overrides: app_storefront_base)
    ├── cart/cartTotals.isml (app_storefront_base)
    ├── cart/miniCart.isml (app_custom, overrides: app_storefront_base)
    │   └── cart/miniCartItem.isml (app_storefront_base)
    └── common/layout/page.isml (app_storefront_base)
```

### プロンプト: テンプレートで使用される pdict 変数

```
[Template Vars] {テンプレートパス} で使用される pdict/ViewData 変数を一覧表示してください。

抽出対象:
1. ${pdict.xxx} 参照
2. <isset> で定義される変数
3. <isloop> のイテレーション変数
4. コントローラーの res.render() で渡されるデータ
```

---

## Dependency Mapping

### プロンプト: カートリッジ依存関係

```
[Deps] {カートリッジ名} の依存関係を表示してください。

解決マップの Section 9 (Dependency Graph Summary) を参照し:
1. require で参照している他カートリッジ（参照数付き）
2. superModule で依存している他カートリッジ
3. Hook で連携しているカートリッジ
4. 逆方向: このカートリッジを参照しているカートリッジ

Mermaid グラフで可視化。
```

### プロンプト: 循環依存の検出

```
[Circular] カートリッジ間またはファイル間の循環依存を検出してください。

検出対象:
1. カートリッジ A → B → A の循環 require
2. ファイルレベルの循環 require
3. 間接的な循環（3ホップ以上）
```

---

## 複合プロンプト

### プロンプト: フル調査

```
[Full Investigation] {Controller}-{Action} について完全な調査を行ってください。

1. ルートの実行フロー（prepend → base → append → events）
2. 使用されるモデルの superModule チェーン
3. レンダリングされるテンプレートの include ツリー
4. 関連する Hook の実行マップ
5. 変更した場合の影響範囲
```

### プロンプト: 新規カートリッジ追加の影響

```
[New Cartridge] カートリッジパスの位置 {N} に新規カートリッジ {名前} を追加した場合の影響を分析してください。

分析対象:
1. 既存の require('*/...') 解決先が変わるファイル
2. superModule チェーンに挿入されるファイル
3. 影響を受けるルートのミドルウェアチェーン
4. テンプレートの解決先が変わるケース
5. Hook の実行順序への影響
```

---

## navigator エージェントへの指示

1. ユーザーの質問を上記カテゴリに分類する
2. 該当するプロンプトテンプレートを適用する
3. まず解決マップを参照し、次に実コードを確認する
4. 回答には必ず**ファイルパス:行番号**を含める
5. 不確実な情報（解決マップにない、動的解決等）は明示的に注記する
6. 複合的な質問は段階的に回答する
