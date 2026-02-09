# Exploration Prompts Catalog

AI エージェントが SFRA コードベースを探索する際に使用する、構造化プロンプトのカタログ。
investigator エージェントがインタラクティブ調査で活用する。

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
| [Business Logic](#business-logic) | ビジネスロジックの調査 | 「商品価格はどこで計算される？」 |
| [Data Flow](#data-flow) | データの流れ追跡 | 「product.availability は API からテンプレートまでどう流れる？」 |
| [Code Pattern](#code-pattern) | パターンの横断検索 | 「Transaction.wrap を使っている全箇所は？」 |

---

## Route Tracing

### プロンプト: ルート実行フロー

```
[Route] {Controller}-{Action} の完全な実行フローを表示してください。

Resolution Map があれば Section 4 (Controller Route Map) を参照。
なければ直接探索:
1. Grep: server\.(get|post|use|append|prepend|replace)\s*\(\s*['"]{Action}
2. 対象: cartridges/*/cartridge/controllers/{Controller}.js
3. カートリッジパス順にソートして実行順序を決定
4. 各ファイルを Read してイベントリスナー（this.on('route:*')）を確認

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

Resolution Map があれば Section 2 (File Resolution Table) を参照。
なければ直接探索:
1. Glob: cartridges/*/cartridge/{相対パス}
2. 存在するカートリッジを全列挙
3. カートリッジパス最左が実際の解決先（Winner）
4. 各ファイルを Read して module.superModule の使用を確認

出力:
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

Resolution Map があれば Section 3 (SuperModule Chains) を参照。
なければ直接探索:
1. 対象ファイルの module.superModule 使用を確認
2. カートリッジパスで自分より右に同名ファイルが存在するか Glob
3. 見つかったファイルも module.superModule を使用しているか Read で確認
4. 再帰的にチェーンを構築（null に到達するまで）

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

Resolution Map があれば Section 7 (Reverse Dependency Index) を参照。
なければ直接探索:
1. Grep: require\s*\(\s*['"].*{ファイル名} で直接参照元を検出
2. 同名ファイルが他カートリッジに存在するか Glob で確認（superModule 依存）
3. Controller の場合: ルート名を抽出し append/prepend している他のファイルを検索
4. テンプレートの場合: <isinclude template="{パス}"> を Grep

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

Resolution Map があれば Section 6 (Hook Registration Map) を参照。
なければ直接探索:
1. 各カートリッジの package.json から hooks エントリを Read
2. 参照先 hooks.json をパースし対象 Hook 名を検索
3. 全カートリッジの登録を列挙（全て実行される）
4. 各スクリプトファイルを Read して実装概要を確認

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

Resolution Map があれば Section 5 (Template Override Map) を参照。
なければ直接探索:
1. Glob: cartridges/*/cartridge/templates/default/{テンプレートパス}.isml
2. カートリッジパス最左が解決先
3. 解決先テンプレートを Read して <isinclude template="..."> を抽出
4. 再帰的に include ツリーを構築

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

Resolution Map があれば Section 9 (Dependency Graph Summary) を参照。
なければ直接探索:
1. 対象カートリッジの全ファイルから require パターンを Grep
2. wildcard require の解決先カートリッジを判定
3. superModule 使用ファイルの解決先カートリッジを判定
4. 逆方向: 他カートリッジから対象への require を Grep
5. 結果を Mermaid グラフで可視化

出力:
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

## Business Logic

### プロンプト: ビジネスロジック調査

```
[Logic] {ビジネスドメインの質問}（例: 商品価格はどこで計算される？）

Resolution Map は不要（直接探索）:
1. ユーザーの質問からキーとなるビジネスドメイン語を抽出
   （例: 価格計算 → "price", "calculate", "pricing"）
2. Grep で関連ファイルを検索
3. Controller → Model → Script の呼び出しチェーンを追跡
4. 該当するビジネスロジックの実装を Read で確認

出力:
1. 関連ファイルの一覧（Controller / Model / Script）
2. 処理フロー（呼び出しチェーン）
3. 主要なロジックのコードスニペット
4. 関連する設定（Preferences、Custom Objects 等）
```

### プロンプト: 特定の処理フロー調査

```
[Flow] {処理名}（例: 注文確定フロー、在庫チェック、クーポン適用）の全体像を調査してください。

調査手順:
1. 関連するコントローラーのルートを特定
2. 呼び出される Model / Helper / Script を追跡
3. DW API の使用箇所を特定（Transaction.wrap、CustomObjectMgr 等）
4. 外部連携（Service Call）があれば特定
5. Hook による拡張ポイントを確認
```

---

## Data Flow

### プロンプト: データ属性の追跡

```
[Data] {データ属性名} が API からテンプレートまでどう流れるか追跡してください。

Resolution Map は不要（直接探索）:
1. 起点を特定（Script API オブジェクト、Model、Controller のいずれか）
2. Controller 内の res.setViewData / res.render を Grep
3. Model のコンストラクタ/メソッドで対象フィールドの設定箇所を Read
4. テンプレート内の ${pdict.xxx} 参照を Grep
5. 全体のデータフローを図示

出力:
1. データの起点（Script API / Model）
2. 変換ステップ（Model → Controller → viewData）
3. テンプレートでの表示（pdict 参照）
4. 中間で加工されるポイント
```

### プロンプト: pdict ライフサイクル

```
[pdict] {Controller}-{Action} で設定される pdict（viewData）の全キーと設定元を一覧にしてください。

調査手順:
1. Controller の各ミドルウェア内の res.setViewData() を Read
2. route:BeforeComplete イベントでの追加データを確認
3. res.render() の第二引数を確認
4. テンプレート側で参照されている ${pdict.*} キーとの整合性を検証
```

---

## Code Pattern

### プロンプト: パターン横断検索

```
[Pattern] {パターン名 or コード断片}（例: Transaction.wrap）の全使用箇所を検索してください。

Resolution Map は不要（直接探索）:
1. ユーザーが指定したパターンを Grep で横断検索
2. 結果をカートリッジ別・ファイルタイプ別に分類
3. 代表的な使用例を Read で確認

出力:
1. 該当箇所の一覧（ファイル:行番号）
2. カートリッジ別の分布
3. ファイルタイプ別の分布（controller / model / script）
4. 代表的な使用例のコードスニペット
```

### プロンプト: サービス呼び出し調査

```
[Service] プロジェクト内の LocalServiceRegistry.createService の全使用箇所と設定を調査してください。

調査手順:
1. Grep: LocalServiceRegistry\.createService で全使用箇所を検出
2. 各サービスの ID と設定ファイルを特定
3. createRequest / parseResponse のコールバックを Read
4. サービスを呼び出しているコントローラー/スクリプトを特定
```

### プロンプト: API 使用パターン調査

```
[API] {DW API クラス名}（例: CustomObjectMgr、OrderMgr、BasketMgr）の全使用箇所を調査してください。

調査手順:
1. Grep: require\s*\(\s*['"]dw/.*{クラス名} で import 箇所を検出
2. 各ファイルでの使用メソッドを特定
3. Transaction.wrap 内での使用を確認
4. エラーハンドリングパターンを確認
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

## investigator エージェントへの指示

1. ユーザーの質問を上記カテゴリに分類する
2. 該当するプロンプトテンプレートを適用する
3. Resolution Map があれば参照し、なければ直接探索する
4. 回答には必ず**ファイルパス:行番号**を含める
5. 不確実な情報（動的解決等）は明示的に注記する
6. 複合的な質問は段階的に回答する
