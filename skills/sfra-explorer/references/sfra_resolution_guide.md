# SFRA Resolution Guide

SFRA のモジュール解決メカニズム完全ガイド。AI がコード探索時に正確なトレースを行うための技術リファレンス。

> **対象読者**: AI エージェント（Claude、Copilot 等）がSFRAコードベースを探索・分析する際の判断基準として使用する。
> 人間の開発者にとっても、SFRA の内部動作を理解するための包括的リファレンスとなる。

---

## 1. カートリッジパス (Cartridge Path)

### 基本概念

カートリッジパスは、Business Manager の **「管理 > サイト > サイトの管理 > サイト > 設定」** で設定されるコロン区切りの文字列である。SFRA におけるすべてのコード解決の基盤となる。

```
app_custom:plugin_wishlists:int_payment:app_storefront_base
```

### 解決優先度

**左側が最優先**である。左から右に向かって優先度が下がる。

```
高優先度 ──────────────────────────────────────→ 低優先度

app_custom > plugin_wishlists > int_payment > app_storefront_base
   (1st)        (2nd)             (3rd)           (4th/ベース)
```

### カートリッジパスの確認方法

Business Manager 上で直接確認するのが最も確実:

```
Business Manager > Administration > Sites > Manage Sites > [サイト名] > Settings
```

プログラムからの取得は制限がある:

```javascript
// ⚠️ 注意: このメソッドはカスタム属性の取得であり、
// サイト設定のカートリッジパスを直接取得するものではない
// 信頼性は環境設定に依存する
var Site = require('dw/system/Site');
var cartridgePath = Site.current.getCustomPreferenceValue('cartridgePath');
```

**AI 探索での確認優先順**:
1. Business Manager 設定（最も正確）
2. `dw.json` の設定ファイル
3. `package.json` のプロジェクト定義
4. ディレクトリ構造からの推測（最低保証）

### 注意事項

- カートリッジパスに含まれないカートリッジのコードは一切解決されない
- 同名ファイルが複数カートリッジに存在する場合、最初にマッチしたもののみが使用される
- パスの順序変更は本番環境に重大な影響を与えるため、慎重に行う

---

## 2. `require('*/cartridge/...')` — ワイルドカード require

### 解決メカニズム

`*` はカートリッジパスの左から右へ走査し、**最初にマッチしたファイルをロード**する。全カートリッジを読み込むわけではない。

### コード例

```javascript
// コントローラーでの使用
var ProductModel = require('*/cartridge/models/product');
```

### 解決の流れ

カートリッジパスが `app_custom:plugin_wishlists:app_storefront_base` の場合:

```
require('*/cartridge/models/product')

走査順:
  1. app_custom/cartridge/models/product.js     → 存在する? → Yes → ロード完了!
  2. plugin_wishlists/cartridge/models/product.js  (走査されない)
  3. app_storefront_base/cartridge/models/product.js (走査されない)
```

`app_custom` に存在しない場合:

```
require('*/cartridge/models/product')

走査順:
  1. app_custom/cartridge/models/product.js     → 存在する? → No
  2. plugin_wishlists/cartridge/models/product.js → 存在する? → No
  3. app_storefront_base/cartridge/models/product.js → 存在する? → Yes → ロード完了!
```

### AI が注意すべき点

`require('*/...')` で解決されるファイルは**カートリッジパスの構成によって異なる**。静的解析だけでは正確な解決先を特定できない場合がある。カートリッジパスの情報が利用可能であれば、それを参照して解決先を判断すること。

---

## 3. `require('~/cartridge/...')` — 現カートリッジ相対 require

### 解決メカニズム

`~` は**現在のカートリッジのルートディレクトリ**を指す。他のカートリッジは一切参照しない。

### コード例

```javascript
// app_custom/cartridge/controllers/Product.js 内
var helper = require('~/cartridge/scripts/helpers/productHelper');
// → app_custom/cartridge/scripts/helpers/productHelper.js を参照
```

### `*` との決定的な違い

| 記法 | 走査範囲 | 用途 |
|------|---------|------|
| `*/cartridge/...` | カートリッジパス全体（左→右） | オーバーライド可能なモジュール |
| `~/cartridge/...` | 現在のカートリッジのみ | そのカートリッジ固有のヘルパー等 |

### 典型的な使い分け

```javascript
// カートリッジパスで解決してほしい場合（オーバーライド可能）
var ProductModel = require('*/cartridge/models/product');

// このカートリッジ固有のユーティリティ（他から参照されない）
var myUtil = require('~/cartridge/scripts/util/myCustomUtil');
```

---

## 4. `require('./...')` と `require('dw/...')` — ローカルと API

### ローカル相対パス (`./`)

通常の Node.js と同じ相対パス解決。現在のファイルからの相対位置で解決する。

```javascript
// app_custom/cartridge/models/product.js 内
var decorators = require('./product/decorators');
// → app_custom/cartridge/models/product/decorators.js
```

### SFCC API (`dw/`)

Salesforce Commerce Cloud のビルトイン API モジュール。カートリッジパスとは無関係に、プラットフォームが直接提供する。

```javascript
var Money = require('dw/value/Money');
var Transaction = require('dw/system/Transaction');
var Logger = require('dw/system/Logger');
var CustomObjectMgr = require('dw/object/CustomObjectMgr');
var BasketMgr = require('dw/order/BasketMgr');
```

### 注意事項

- `dw/` モジュールはサーバーサイドのみで利用可能
- クライアントサイド JavaScript からは `dw/` モジュールを参照できない
- `dw/` モジュールの挙動はプラットフォームバージョンに依存する

---

## 5. `require('cartridge_name/cartridge/...')` — 明示カートリッジ指定

### 解決メカニズム

カートリッジ名を直接指定してモジュールをロードする。**カートリッジパスの優先順位を無視**し、指定されたカートリッジから直接読み込む。

### コード例

```javascript
// plugin_wishlists のモデルを明示的に参照
var WishlistModel = require('plugin_wishlists/cartridge/models/wishlist');

// app_storefront_base のヘルパーを直接参照
var baseHelper = require('app_storefront_base/cartridge/scripts/helpers/productHelpers');
```

### 使用場面

- 特定のカートリッジのモジュールを確実に参照したい場合
- オーバーライドチェーンをバイパスしたい場合
- プラグイン間の明示的な依存関係を表現する場合

### 注意事項

- 指定されたカートリッジがカートリッジパスに存在しない場合、エラーとなる
- カートリッジパスの順序とは無関係に解決されるため、依存関係が暗黙的になりやすい
- 保守性の観点から、可能な限り `*/` を使用し、明示指定は必要最小限にすべき

---

## 6. `module.superModule` — 継承チェーン

### 解決メカニズム

`module.superModule` は、カートリッジパスにおいて**現在のカートリッジより右側（低優先度側）にある同名モジュール**を返す。常に `app_storefront_base` を指すわけではない。

### チェーントレースの具体例

カートリッジパス: `app_custom:plugin_wishlists:app_storefront_base`

#### ケース1: 間にプラグインがある場合

```
ファイル構成:
  app_custom/cartridge/models/product.js         → 存在する
  plugin_wishlists/cartridge/models/product.js   → 存在する
  app_storefront_base/cartridge/models/product.js → 存在する

app_custom/models/product.js の module.superModule
  → 検索: plugin_wishlists/models/product.js? → あり!

plugin_wishlists/models/product.js の module.superModule
  → 検索: app_storefront_base/models/product.js? → あり!

app_storefront_base/models/product.js の module.superModule
  → null（終端）

Chain: app_custom → plugin_wishlists → app_storefront_base → null
```

#### ケース2: 間のカートリッジに同名ファイルがない場合

```
ファイル構成:
  app_custom/cartridge/models/product.js         → 存在する
  plugin_wishlists/cartridge/models/product.js   → 存在しない
  app_storefront_base/cartridge/models/product.js → 存在する

app_custom/models/product.js の module.superModule
  → 検索: plugin_wishlists/models/product.js? → なし
  → 検索: app_storefront_base/models/product.js? → あり!

Chain: app_custom → app_storefront_base → null
```

### Decorator パターン（プロトタイプ継承）

```javascript
'use strict';

var base = module.superModule;

/**
 * ProductModel のカスタム拡張
 * @param {dw.catalog.Product} product - 商品オブジェクト
 * @param {Object} config - 設定オブジェクト
 */
function ProductModel(product, config) {
    base.call(this, product, config);        // 親コンストラクタを呼び出し
    this.customField = product.custom.myField; // カスタム属性を追加
    this.isSpecialProduct = checkSpecial(product);
}

ProductModel.prototype = Object.create(base.prototype);

// メソッドのオーバーライド
ProductModel.prototype.getPrice = function () {
    var basePrice = base.prototype.getPrice.call(this);
    // カスタムロジックを適用
    return applyCustomDiscount(basePrice);
};

module.exports = ProductModel;
```

### Mixin パターン（オブジェクト拡張）

```javascript
'use strict';

var base = module.superModule;

/**
 * base が関数ではなくオブジェクト/ユーティリティの場合
 */
var exportObj = Object.assign({}, base, {
    customMethod: function () {
        // カスタムロジック
    },
    // 既存メソッドのオーバーライド
    existingMethod: function () {
        var result = base.existingMethod.apply(this, arguments);
        // 拡張ロジック
        return result;
    }
});

module.exports = exportObj;
```

### `module.superModule` が `null` の場合

```javascript
'use strict';

var base = module.superModule;

if (base) {
    // 継承チェーンが存在する場合
    function Model(params) {
        base.call(this, params);
    }
    Model.prototype = Object.create(base.prototype);
} else {
    // ベースカートリッジ（終端）の場合
    function Model(params) {
        this.init(params);
    }
}

module.exports = Model;
```

---

## 7. `server.extend` / `append` / `prepend` / `replace`

### `server.extend(module.superModule)` — コントローラー継承

全ルートとミドルウェアチェーンを継承する。新規ルートの追加も可能。

```javascript
'use strict';

var server = require('server');
server.extend(module.superModule);

// 既存ルート Show に対して append
server.append('Show', function (req, res, next) {
    // 追加のデータ処理
    next();
});

// 新規ルート CustomAction を追加
server.get('CustomAction', function (req, res, next) {
    res.render('product/customAction');
    next();
});

module.exports = server.exports();
```

### `server.append(routeName, middleware)` — ミドルウェア末尾追加

指定ルートのミドルウェアチェーン**末尾**に追加する。元の処理は**必ず実行される**。

```javascript
server.append('Show', function (req, res, next) {
    var viewData = res.getViewData();
    viewData.customAttribute = 'additionalData';
    res.setViewData(viewData);
    next(); // 必須: 次のミドルウェアまたは完了処理に遷移
});
```

**重要**: `next()` を呼ばないとチェーンが中断し、レスポンスが返らない。

### `server.prepend(routeName, middleware)` — ミドルウェア先頭追加

指定ルートのミドルウェアチェーン**先頭**に追加する。元の処理は**必ず実行される**。

```javascript
server.prepend('Show', function (req, res, next) {
    // Base のミドルウェアより先に実行される
    var isAllowed = checkAccess(req);
    if (!isAllowed) {
        res.redirect(URLUtils.url('Home-Show'));
        return next();
    }
    next();
});
```

### `server.replace(routeName, middleware)` — ルート完全置換

指定ルートを**完全に置き換える**。元の処理は**実行されない**。元のイベントリスナーも**破棄**される。

```javascript
server.replace('Show', server.middleware.https, function (req, res, next) {
    // Base の Show ルートは完全に無視される
    // 全てのロジックをここで再実装する必要がある
    var productId = req.querystring.pid;
    var ProductFactory = require('*/cartridge/scripts/factories/product');
    var product = ProductFactory.get({ pid: productId });

    res.render('product/productDetails', {
        product: product
    });
    next();
});
```

### 実行順序の図解

```
[リクエスト受信]
       ↓
    prepend ミドルウェア(1) → next()
       ↓
    prepend ミドルウェア(2) → next()
       ↓
    Base ミドルウェア(1) → next()
       ↓
    Base ミドルウェア(2) → next()
       ↓
    append ミドルウェア(1) → next()
       ↓
    append ミドルウェア(2) → next()
       ↓
    route:BeforeComplete イベント発火
       ↓
    route:Complete イベント発火
       ↓
   [レスポンス送信]
```

### `setViewData` with `append` の注意点

`server.append` を使用して `setViewData` でデータを変更する場合の落とし穴:

```javascript
// ❌ 問題のあるパターン
server.append('Show', function (req, res, next) {
    // Base 側の Show ミドルウェアは既に実行済み
    // Base 側で行われた全ての計算（DB アクセス、API 呼び出し等）は
    // 既に完了している
    var viewData = res.getViewData();
    viewData.price = calculateNewPrice(); // 上書き
    res.setViewData(viewData);
    next();
});
```

**問題点**:
- レンダリングは1回だが、Base 側のデータ準備ロジック（DB クエリ、計算等）は**必ず実行される**
- Base 側の結果を上書きする場合、Base 側の処理が無駄になる
- 意図しないデータの上書き（Base 側が `route:BeforeComplete` でデータを変更する場合）のリスクがある

```javascript
// ✅ 推奨パターン: replace でロジック全体を差し替え
server.replace('Show', function (req, res, next) {
    // 必要なロジックのみを実装
    var viewData = calculateNewPrice();
    res.render('product/productDetails', viewData);
    next();
});
```

---

## 8. Hook — フック解決

### Hook 定義の仕組み

Hook の定義ファイルの場所は、各カートリッジの `package.json` 内の `hooks` エントリによって決定される。`package.json` が hooks JSON ファイルへの相対パスを指定する。

```json
// package.json
{
    "name": "app_custom",
    "hooks": "./cartridge/hooks.json"
}
```

上記の `hooks` エントリが指す JSON ファイル（通常は `hooks.json`）にフック定義を記述する:

```json
// cartridge/hooks.json（package.json の hooks エントリから参照される）
{
    "hooks": [
        {
            "name": "dw.order.calculate",
            "script": "./cartridge/scripts/hooks/calculateHook"
        },
        {
            "name": "app.payment.processor.CREDIT_CARD",
            "script": "./cartridge/scripts/hooks/payment/creditCardProcessor"
        },
        {
            "name": "dw.ocapi.shop.basket.afterPOST",
            "script": "./cartridge/scripts/hooks/ocapi/basketAfterPost"
        }
    ]
}
```

### 解決ルール

**重要**: 同一拡張ポイントに対して**カートリッジパス内の全カートリッジで登録された Hook が全て実行される**。`require('*/...')` の「最初のマッチのみ」とは異なり、Hook は全マッチが実行される。

> "At run time, B2C Commerce runs all hooks registered for an extension point in all cartridges in your cartridge path."
> — [Salesforce SFRA Hooks Guide](https://developer.salesforce.com/docs/commerce/b2c-commerce/guide/b2c-sfra-hooks.html)

```
カートリッジパス: app_custom:plugin_payment:app_storefront_base

dw.order.calculate を呼び出し:
  1. app_custom/hooks.json → dw.order.calculate 定義あり? → Yes → 実行!
  2. plugin_payment/hooks.json → dw.order.calculate 定義あり? → Yes → 実行!
  3. app_storefront_base/hooks.json → dw.order.calculate 定義あり? → Yes → 実行!

→ 全カートリッジの定義が順番に実行される（カートリッジパス左→右の順序）
```

### Hook の呼び出し側

```javascript
var HookMgr = require('dw/system/HookMgr');

// Hook が登録されているか確認してから呼び出し
if (HookMgr.hasHook('dw.order.calculate')) {
    HookMgr.callHook('dw.order.calculate', 'calculate', basket);
}
```

### Hook 実行の重要な特性

- `HookMgr.callHook` は**全カートリッジの同名 Hook を順番に実行する**（カートリッジパス順）
- `require('*/...')` や ISML テンプレートの「最初のマッチのみ」の解決ルールとは**根本的に異なる**
- 複数カートリッジで同一拡張ポイントの Hook を登録する場合、各カートリッジの Hook が独立して実行されることを考慮する
- Hook の実行順序はカートリッジパスの順序に従う（左が先、右が後）

### Hook 実装の例

```javascript
// cartridge/scripts/hooks/calculateHook.js
'use strict';

/**
 * 注文の計算 Hook
 * @param {dw.order.Basket} basket - バスケット
 */
function calculate(basket) {
    var ShippingMgr = require('dw/order/ShippingMgr');
    var TaxMgr = require('dw/order/TaxMgr');

    // 配送料計算
    ShippingMgr.applyShippingCost(basket);

    // 税金計算
    TaxMgr.applyTax(basket);

    return;
}

exports.calculate = calculate;
```

---

## 9. ISML テンプレート解決

### 基本的な解決ルール

ISML テンプレートもカートリッジパス順で解決される。**最初にマッチしたテンプレートがレンダリングされる**。

```
res.render('product/productDetails')

走査順:
  1. app_custom/cartridge/templates/default/product/productDetails.isml       → あり → 使用!
  2. plugin_wishlists/cartridge/templates/default/product/productDetails.isml  (走査されない)
  3. app_storefront_base/cartridge/templates/default/product/productDetails.isml (走査されない)
```

### `isinclude` の解決

`isinclude` もカートリッジパス順で解決される。

```html
<!-- product/productDetails.isml (app_custom) -->
<isdecorate template="common/layout/page">
    <isinclude template="product/components/pricing" />
    <!-- ↑ カートリッジパス順で最初にマッチする pricing.isml が使用される -->
</isdecorate>
```

### ローカル include と リモート include の違い

| 種類 | 記法 | 処理 |
|------|------|------|
| ローカル include | `<isinclude template="..." />` | 同一リクエスト内でテンプレートを展開 |
| リモート include | `<isinclude url="${URLUtils.url('Controller-Route')}" />` | 別リクエストとして実行（キャッシュ可能） |

```html
<!-- ローカル include: 同一リクエスト内で展開 -->
<isinclude template="product/components/pricing" />

<!-- リモート include: 別リクエストとして処理される -->
<isinclude url="${URLUtils.url('Product-ShowQuickView', 'pid', pdict.product.id)}" />
```

### ロケール別テンプレート

```
templates/
  ├── default/          ← フォールバック
  │   └── product/
  │       └── details.isml
  ├── ja_JP/            ← 日本語ロケール優先
  │   └── product/
  │       └── details.isml
  └── en_US/            ← 英語ロケール優先
      └── product/
          └── details.isml
```

解決順: ロケール固有テンプレート → `default/` テンプレート

---

## 10. `modules/` フォルダ — グローバルモジュール

### 基本概念

`modules/` フォルダは**カートリッジフォルダのピア（同階層）**に配置される。カートリッジ内部のサブディレクトリではない。ここに配置されたファイルは、**パス指定なしで直接 `require` できる**グローバルモジュールとなる。

> "The modules folder is a peer of cartridge folders"
> — [Salesforce Developers: SFRA Modules](https://developer.salesforce.com/docs/commerce/account-manager/guide/b2c-sfra-modules.html)

### ディレクトリ構造

```
project_root/
  ├── cartridges/
  │   ├── app_storefront_base/
  │   │   └── cartridge/
  │   │       ├── controllers/
  │   │       ├── models/
  │   │       └── ...
  │   ├── app_custom/
  │   │   └── cartridge/
  │   │       └── ...
  │   └── ...
  └── modules/                    ← cartridges/ と同階層（ピア）
      └── server/
          └── server.js           ← require('server') で参照可能
```

> "Includes the app_storefront_base cartridge and a modules cartridge that includes the server module"
> — [Salesforce Developers: Build SFRA](https://developer.salesforce.com/docs/commerce/b2c-commerce/guide/b2c-build-sfra.html)

### 使用例

```javascript
// modules/server/server.js は以下のように参照できる
var server = require('server');
// パスの指定は不要
```

### SFRA で最も重要な modules

トップレベルの `modules/` フォルダに配置されている `server` モジュールが最も代表的な例である。これが `require('server')` で参照できる理由である。`server` モジュールは Route、ミドルウェアチェーン、EventEmitter ベースのルートライフサイクルを提供する SFRA のコアモジュールである。

### 注意事項

- `modules/` はカートリッジの**外側**（ピア）に配置される。カートリッジ内ではない
- `modules/` 内のファイルは全カートリッジから参照可能
- カートリッジパスによる優先順位は適用されない
- 同名モジュールが複数の `modules/` に存在する場合の挙動はプラットフォーム依存

---

## 11. イベント駆動パターン (EventEmitter)

### 基本概念

SFRA の Route は Node.js の `EventEmitter` を継承している。ミドルウェアチェーンとは別の**イベントベースの実行フロー**が存在する。

### イベント実行順序

```
[リクエスト受信]
       ↓
  route:Start
       ↓
  route:Step → ミドルウェア(1) → next()
       ↓
  route:Step → ミドルウェア(2) → next()
       ↓
  route:Step → ミドルウェア(3) → next()
       ↓
  route:BeforeComplete
       ↓
  route:Complete
       ↓
  [レスポンス送信]
```

### redirect 発生時のフロー

```
[リクエスト受信]
       ↓
  route:Start
       ↓
  route:Step → ミドルウェア(1) → next()
       ↓
  route:Step → ミドルウェア(2) → res.redirect(...) → next()
       ↓
  route:Redirect  ← チェーン中断! BeforeComplete/Complete は発火しない
       ↓
  [リダイレクトレスポンス送信]
```

### 主要イベント一覧

| イベント | タイミング | 用途 |
|---------|-----------|------|
| `route:Start` | 最初のミドルウェア実行前 | 初期化処理、リクエストログ |
| `route:Step` | 各ミドルウェア実行前 | デバッグ、パフォーマンス計測 |
| `route:Redirect` | `redirect` 検出時 | チェーン中断、リダイレクト処理 |
| `route:BeforeComplete` | 全ミドルウェア完了後 | DB 書き込み、フォーム処理、最終データ加工 |
| `route:Complete` | 最終完了時 | 後処理、クリーンアップ、ログ出力 |

### `this.on('route:BeforeComplete')` の使用パターン

```javascript
server.get('Show', function (req, res, next) {
    var ProductFactory = require('*/cartridge/scripts/factories/product');
    var product = ProductFactory.get({ pid: req.querystring.pid });

    res.setViewData({ product: product });

    // route:BeforeComplete でトランザクション処理
    this.on('route:BeforeComplete', function (req, res) {
        var formData = res.getViewData();
        var Transaction = require('dw/system/Transaction');

        Transaction.wrap(function () {
            // DB 書き込み処理
            var viewHistory = require('*/cartridge/scripts/helpers/viewHistory');
            viewHistory.addToRecentlyViewed(formData.product.id);
        });

        // ビューデータの最終加工
        formData.additionalInfo = computeAdditionalInfo(formData.product);
        res.setViewData(formData);
    });

    next();
});
```

### フォーム処理での典型例

```javascript
server.post('SaveAddress', function (req, res, next) {
    var addressForm = server.forms.getForm('address');

    // フォームバリデーション
    if (addressForm.valid) {
        this.on('route:BeforeComplete', function (req, res) {
            var Transaction = require('dw/system/Transaction');
            var CustomerMgr = require('dw/customer/CustomerMgr');

            Transaction.wrap(function () {
                var customer = CustomerMgr.getCustomerByCustomerNumber(
                    req.currentCustomer.profile.customerNo
                );
                var addressBook = customer.getAddressBook();
                var address = addressBook.createAddress(addressForm.addressId.value);
                address.setFirstName(addressForm.firstName.value);
                address.setLastName(addressForm.lastName.value);
                // ... 他のフィールド
            });

            res.json({ success: true });
        });
    } else {
        res.json({ success: false, errors: addressForm.errors });
    }

    next();
});
```

### AI が見落としやすいポイント

1. **`route:BeforeComplete` はミドルウェアチェーンの外で実行される**: `next()` は不要であり、呼んではならない
2. **`this` のスコープ**: ミドルウェア関数内の `this` は Route オブジェクトを指す。アロー関数を使うと `this` が変わるため、`function` キーワードを使用すること
3. **`server.append` + `this.on('route:BeforeComplete')`**: append 先でも `route:BeforeComplete` リスナーを追加可能だが、Base 側のリスナーも実行される。実行順序は登録順
4. **`server.replace` はリスナーも破棄する**: `replace` すると Base 側で登録された `route:BeforeComplete` リスナーも全て破棄される

---

## 12. AI がよくする誤解 TOP 13

| # | 誤解 | 正しい理解 |
|---|------|-----------|
| 1 | `require('*/...')` は全カートリッジを読む | カートリッジパスの左から右へ走査し、**最初のマッチのみ**ロードする |
| 2 | `server.append` で `setViewData` すると double execution が起きる | レンダリングは1回だが、Base 側のロジック（DB アクセス、計算等）は**常に実行される**。ViewData の変更が目的なら `server.replace` を推奨 |
| 3 | `module.superModule` は常に `app_storefront_base` を指す | カートリッジパスで**現在より右側にある最初の同名モジュール**を指す。間にプラグインがあればそちらが返る |
| 4 | `server.extend` と `server.append` は同じ | `server.extend(module.superModule)` は**全ルート継承**、`server.append` は**特定ルートへの後処理追加** |
| 5 | Hook はカートリッジパスで最初のマッチのみ実行 | `HookMgr.callHook` は**全カートリッジの登録済み Hook を全て実行**する。`require('*/...')` の「最初のマッチのみ」とは異なる |
| 6 | ISML の `isinclude` はカートリッジパス無関係 | `isinclude template="..."` もカートリッジパス順で解決される |
| 7 | `require('~/...')` はプロジェクトルート | `~` は**現在のカートリッジのルート**を指す。プロジェクトルートではない |
| 8 | `server.replace` は元のルートに追加する | 元のルートを**完全に置き換える**。元の処理は一切実行されない |
| 9 | カートリッジパスの右側が優先 | **左側（先頭）が最優先**。右に行くほど優先度が下がる |
| 10 | `modules/` はカートリッジパスで解決 | `modules/` フォルダ内のファイルは**パス指定なしで直接参照可能**。カートリッジパスによる優先順位の仕組みとは異なる |
| 11 | `this.on('route:BeforeComplete')` はミドルウェアと同時実行 | 全ミドルウェアの `next()` が完了した**後に実行**される |
| 12 | `server.replace` しても元のイベントリスナーは残る | `replace` すると元のルートに登録された**リスナーも全て破棄**される |
| 13 | `this.emit` はカスタムイベント用のみ | Route の `emit` は SFRA の**コアメカニズム**。`route:Start`、`route:Step` 等の標準イベントもこの仕組みで動作する |

---

## 13. 効率的な AI 探索フロー

### 推奨ステップ

SFRA コードベースを探索する際は、以下の順序で進めることを推奨する。

#### Step 1: 解決マップ参照

プロジェクトに解決マップ（`resolution_map.json` 等）が存在する場合、まずそれを参照する。カートリッジパスとファイルのマッピングが事前に定義されていれば、探索を大幅に短縮できる。

#### Step 2: カートリッジパス確認

```
確認対象:
  - site.xml または Business Manager 設定
  - package.json 内のカートリッジ定義
  - .dw.json / dw.json の設定

カートリッジパスの例:
  app_custom:plugin_wishlists:int_payment:app_storefront_base
```

#### Step 3: require / superModule チェーントレース

```
対象ファイルの require 文を全て抽出:
  - require('*/...') → カートリッジパス順で解決先を特定
  - require('~/...') → 現在のカートリッジ内で解決
  - require('./...')  → 相対パスで解決
  - module.superModule → 継承チェーンをトレース

チェーンの終端（null）まで追跡すること。
```

#### Step 4: ミドルウェアチェーン + イベントリスナー確認

```
コントローラーの場合:
  1. server.extend(module.superModule) の有無
  2. server.append / prepend / replace の対象ルート
  3. this.on('route:BeforeComplete') の登録
  4. ミドルウェアの引数リスト（server.middleware.https 等）

実行順序を正確に把握する:
  prepend → base → append → BeforeComplete → Complete
```

#### Step 5: テンプレート解決確認

```
res.render() の引数からテンプレートパスを特定:
  1. カートリッジパス順で ISML ファイルを検索
  2. テンプレート内の isinclude を再帰的にトレース
  3. ロケール別テンプレートの存在確認
```

#### Step 6: 実コードの読み込み

```
上記ステップで特定したファイルを実際に読み込み:
  1. 解決先のファイル内容を確認
  2. 継承チェーン全体のロジックフローを把握
  3. Hook の実装を確認
  4. テンプレートの実際のマークアップを確認
```

### 探索時のチェックリスト

- [ ] カートリッジパスの順序を正しく把握しているか
- [ ] `require('*/...')` の解決先は最初のマッチか（全マッチではない）
- [ ] `module.superModule` のチェーンは終端まで追跡したか
- [ ] `server.append` / `prepend` / `replace` の区別は正しいか
- [ ] `route:BeforeComplete` リスナーの存在を見落としていないか
- [ ] Hook は全カートリッジの登録分が全て実行されることを理解しているか
- [ ] ISML テンプレートの解決先は正しいか
- [ ] `server.replace` 時に元のリスナーが破棄されることを考慮したか

---

## Sources

### 公式ドキュメント

- [Salesforce Help: Cartridge Search Path](https://help.salesforce.com/s/articleView?id=cc.b2c_cartridge_search_path.htm)
- [Salesforce Developers: SFRA Middleware](https://developer.salesforce.com/docs/commerce/b2c-commerce/guide/b2c-sfra-middleware.html)
- [Salesforce Developers: SFRA Hooks](https://developer.salesforce.com/docs/commerce/b2c-commerce/guide/b2c-sfra-hooks.html)
- [Salesforce Developers: SFRA Modules](https://developer.salesforce.com/docs/commerce/account-manager/guide/b2c-sfra-modules.html)
- [Salesforce Developers: Build SFRA](https://developer.salesforce.com/docs/commerce/b2c-commerce/guide/b2c-build-sfra.html)
- [SFCC Script API: RequestHooks](https://salesforcecommercecloud.github.io/b2c-dev-doc/docs/current/scriptapi/html/api/class_dw_system_RequestHooks.html)
- [SFRA GitHub - server.js](https://github.com/SalesforceCommerceCloud/storefront-reference-architecture/blob/master/cartridges/app_storefront_base/cartridge/scripts/server.js)
- [SFRA GitHub - route.js](https://github.com/SalesforceCommerceCloud/storefront-reference-architecture/blob/master/cartridges/app_storefront_base/cartridge/scripts/route.js)
- [SFRA JSDoc](https://salesforcecommercecloud.github.io/storefront-reference-architecture/)

### 関連リソース

- [Salesforce Developers: ISML Templates](https://developer.salesforce.com/docs/commerce/b2c-commerce/guide/b2c-isml-templates.html)
- [Salesforce Developers: Controllers](https://developer.salesforce.com/docs/commerce/b2c-commerce/guide/b2c-sfra-controllers.html)
- [Salesforce Developers: Forms](https://developer.salesforce.com/docs/commerce/b2c-commerce/guide/b2c-sfra-forms.html)
