# SFRA Anti-Patterns Catalog

避けるべきパターンとその修正方法。

## P0 Anti-Patterns (Blocker)

### AP-001: pdict Override

**Pattern**: 標準の pdict 変数を上書き

```javascript
// ❌ WRONG
pdict.product = customProduct;
pdict.basket = modifiedBasket;
pdict.order = enhancedOrder;
pdict.customer = decoratedCustomer;
```

**Risk**: テンプレートで予期しない動作、他の cartridge との競合

**Fix**:
```javascript
// ✓ CORRECT: Use different names
pdict.customProduct = customProduct;
pdict.enhancedBasket = modifiedBasket;
```

---

### AP-002: pdict Delete

**Pattern**: pdict プロパティを削除

```javascript
// ❌ WRONG
delete pdict.recommendations;
delete pdict.upsellProducts;
```

**Risk**: テンプレートエラー、undefined 参照

**Fix**:
```javascript
// ✓ CORRECT: Use flags
pdict.hideRecommendations = true;
pdict.showUpsell = false;
```

---

### AP-003: eval() Usage

**Pattern**: eval() でユーザー入力を実行

```javascript
// ❌ WRONG
var filter = req.querystring.filter;
eval(filter);  // Remote Code Execution!

var expression = req.form.expression;
var result = eval(expression);
```

**Risk**: リモートコード実行（RCE）、サーバー完全制御

**Fix**:
```javascript
// ✓ CORRECT: Allowlist
var ALLOWED_FILTERS = {
    'price': priceFilter,
    'name': nameFilter
};
var filter = ALLOWED_FILTERS[req.querystring.filter];
if (filter) filter(data);
```

---

### AP-004: CSP unsafe-inline / unsafe-eval

**Pattern**: httpHeadersConf.json で unsafe ディレクティブを使用

```json
// ❌ WRONG: unsafe-inline allows XSS bypass
{
  "Content-Security-Policy": "script-src 'self' 'unsafe-inline' 'unsafe-eval'"
}
```

**Risk**: XSS 攻撃を CSP で防御できない、PCI v4.0 非準拠

**Fix**:
```json
// ✓ CORRECT: nonce-based CSP with reporting
{
  "Content-Security-Policy": "script-src 'self' 'nonce-{random}'; report-uri /csp-report"
}
```

---

## P1 Anti-Patterns (Major)

### AP-101: Session Dependency

**Pattern**: Session オブジェクトへの直接依存

```javascript
// ❌ WRONG
var customerId = session.customer.ID;
session.custom.lastVisit = new Date();
session.privacy.accepted = true;
```

**Risk**: Headless/SCAPI 環境で動作しない

**Fix**:
```javascript
// ✓ CORRECT: Use request context
var customerId = req.currentCustomer.ID;

// For headless: Use tokens
var customer = CustomerMgr.getCustomerByToken(token);
```

---

### AP-102: God Object

**Pattern**: 1000行以上の巨大ファイル

```javascript
// ❌ WRONG: ProductHelper.js (1500 lines)
// - Product loading
// - Price calculation
// - Inventory check
// - Recommendations
// - Reviews
// - SEO
// - Caching
// - ...
```

**Risk**: 保守困難、テスト困難、変更リスク高

**Fix**:
```
// ✓ CORRECT: Split by responsibility
scripts/
├── product/
│   ├── productLoader.js
│   ├── priceCalculator.js
│   └── inventoryChecker.js
├── recommendation/
│   └── recommendationEngine.js
└── seo/
    └── seoHelper.js
```

---

### AP-103: Double Execution

**Pattern**: server.append() で ViewData 変更

```javascript
// ❌ WRONG: Causes controller to execute twice!
server.append('Show', function(req, res, next) {
    var viewData = res.getViewData();
    viewData.customField = 'value';
    res.setViewData(viewData);  // Triggers re-execution!
    next();
});
```

**Risk**: パフォーマンス低下、サービス二重呼び出し

**Fix**:
```javascript
// ✓ CORRECT: Use replace
server.replace('Show', function(req, res, next) {
    // Call original logic if needed
    var originalModule = require('*/controllers/Original');
    originalModule.Show.call(this, req, res, function() {
        var viewData = res.getViewData();
        viewData.customField = 'value';
        res.setViewData(viewData);
        next();
    });
});
```

---

### AP-104: Transaction in Loop

**Pattern**: ループ内で Transaction を作成

```javascript
// ❌ WRONG: Creates N transactions
products.forEach(function(product) {
    Transaction.wrap(function() {
        product.custom.updated = new Date();
    });
});
```

**Risk**: パフォーマンス低下、データ整合性問題

**Fix**:
```javascript
// ✓ CORRECT: Single transaction
Transaction.wrap(function() {
    products.forEach(function(product) {
        product.custom.updated = new Date();
    });
});

// Or chunked for large data
var chunkSize = 100;
for (var i = 0; i < products.length; i += chunkSize) {
    var chunk = products.slice(i, i + chunkSize);
    Transaction.wrap(function() {
        chunk.forEach(function(p) {
            p.custom.updated = new Date();
        });
    });
}
```

---

### AP-105: Circular Dependency

**Pattern**: モジュール間の循環参照

```javascript
// moduleA.js
var moduleB = require('./moduleB');

// moduleB.js
var moduleA = require('./moduleA');  // Circular!
```

**Risk**: 初期化順序問題、予期しない undefined

**Fix**:
```javascript
// ✓ CORRECT: Extract common dependency
// common.js - Shared utilities
// moduleA.js - requires common
// moduleB.js - requires common

// Or: Dependency injection
function moduleA(deps) {
    // Use deps.moduleB instead of require
}
```

---

### AP-106: ISML Cache Tag (2024+)

**Pattern**: ISML で `<iscache>` タグを使用

```xml
<!-- ❌ WRONG: Deprecated approach -->
<iscache type="relative" hour="24"/>
```

**Risk**: ベストプラクティス違反、キャッシュ制御の柔軟性低下

**Fix**:
```javascript
// ✓ CORRECT: Use Response#setExpires in controller
server.get('Show', function(req, res, next) {
    res.setExpires(new Date(Date.now() + 24 * 60 * 60 * 1000));
    // ...
    next();
});
```

**Source**: [SFRA JSDoc - Caching Responses](https://salesforcecommercecloud.github.io/b2c-dev-doc/docs/current/sfrajsdoc/js/server/tutorial-CachingResponses.html)

---

### AP-107: Cache Key Pollution (2024+)

**Pattern**: 意味のない URL パラメータでキャッシュキーを増殖

```javascript
// ❌ WRONG: Position parameter breaks cache
var tileUrl = URLUtils.url('Product-Show', 'pid', productID, 'position', index);
```

**Risk**: キャッシュヒット率低下、パフォーマンス悪化

**Fix**:
```javascript
// ✓ CORRECT: Only essential parameters
var tileUrl = URLUtils.url('Product-Show', 'pid', productID);
// Position can be handled client-side or via data attribute
```

**Source**: [Caching Strategies](https://developer.salesforce.com/docs/commerce/ocapi/guide/caching-strategies-sk.html)

---

### AP-108: Search Result Post-Processing (2024+)

**Pattern**: 検索結果の後処理や variation 反復

```javascript
// ❌ WRONG: Post-processing search results
var searchResults = ProductSearchModel.search();
searchResults.forEach(function(product) {
    // Heavy processing per product
    product.variations.forEach(function(v) { ... });
});
```

**Risk**: 重大なパフォーマンス低下

**Fix**:
```javascript
// ✓ CORRECT: Use search refinements and sorting
var searchResults = ProductSearchModel.search();
// Let the search engine handle filtering/sorting
// Avoid iteration over variations
```

**Source**: [B2C Site Performance](https://developer.salesforce.com/docs/commerce/ocapi/guide/b2c-site-performance.html)

---

### AP-109: Include Content-Type Mismatch (2024+)

**Pattern**: include 側で content type が不一致

```xml
<!-- ❌ WRONG: Parent sets htmlcontent, include doesn't -->
<iscontent type="text/html" charset="UTF-8"/>
<isinclude template="components/snippet"/>
<!-- snippet.isml has no iscontent → encoding may fail -->
```

**Risk**: XSS 脆弱性（エンコードが効かない）

**Fix**:
```xml
<!-- ✓ CORRECT: Consistent content type -->
<!-- snippet.isml -->
<iscontent type="text/html" charset="UTF-8" compact="true"/>
<!-- Content here -->
```

**Source**: [Cross-Site Scripting Prevention](https://sfcclearning.com/infocenter/content/b2c_commerce/topics/b2c_security_best_practices/b2c_cross_site_scripting.php)

---

### AP-110: Storefront Toolkit Dependency (2025+)

**Pattern**: Storefront Toolkit API への依存（25.7 でデフォルト無効化 — 要リリースノート確認）

```javascript
// ❌ WRONG: Storefront Toolkit disabled in 25.7
var toolkit = dw.system.StorefrontToolkit;
if (isStorefrontToolkitEnabled()) { ... }
```

**Risk**: 25.7 以降で実行時エラーの可能性

**Fix**:
```javascript
// ✓ CORRECT: Use alternative debugging tools
// Business Manager Code Profiler or custom debug utilities
```

---

### AP-111: OCAPI Leading Zero Version (2026+)

**Pattern**: OCAPI バージョン番号に先行ゼロ（26.2 で拒否 — 要リリースノート確認）

```javascript
// ❌ WRONG: Leading zero rejected from 26.2
var endpoint = '/s/-/dw/shop/v024_05/products';

// ✓ CORRECT: No leading zero
var endpoint = '/s/-/dw/shop/v24_5/products';
```

**Risk**: 26.2 以降で API 呼び出しエラー（400 Bad Request）

---

### AP-112: Legacy Pipelet Usage

**Pattern**: レガシー Pipelet/Pipeline API の使用（非推奨）

```javascript
// ❌ WRONG: Legacy Pipelet API (deprecated — 要リリースノート確認)
dw.system.Pipelet;
PipeletExecution;
```

**Risk**: レガシー API はメンテナンス停止。将来のリリースで削除の可能性あり

**Fix**: SFRA Controllers に移行

> **注意**: "Workflow Rules 2025.12.31 終了" は Salesforce Core (CRM) の機能であり、
> B2C Commerce (SFCC) とは異なる。SFCC の Pipelet は個別のリリースノートで廃止時期を確認すること。

---

## P2 Anti-Patterns (Minor)

### AP-201: Magic Numbers

**Pattern**: ハードコードされた数値

```javascript
// ❌ WRONG
if (quantity > 99) { ... }
var timeout = 30000;
var maxItems = 50;
```

**Fix**:
```javascript
// ✓ CORRECT: Named constants
var MAX_QUANTITY = 99;
var SERVICE_TIMEOUT_MS = 30000;
var MAX_CART_ITEMS = 50;
```

---

### AP-202: Primitive Obsession

**Pattern**: オブジェクトの代わりにプリミティブ

```javascript
// ❌ WRONG
function processAddress(street, city, state, zip, country) { ... }
```

**Fix**:
```javascript
// ✓ CORRECT
function processAddress(address) {
    // address.street, address.city, etc.
}
```

---

### AP-203: Copy-Paste Code

**Pattern**: 同じコードの重複

```javascript
// ❌ WRONG: Same validation in 5 files
if (!email || !email.match(/^[^@]+@[^@]+$/)) {
    res.json({ error: 'Invalid email' });
}
```

**Fix**:
```javascript
// ✓ CORRECT: Centralized helper
// validationHelper.js
function validateEmail(email) {
    return email && email.match(/^[^@]+@[^@]+$/);
}
```

---

### AP-204: String Concatenation in Logger

**Pattern**: ログでの文字列連結

```javascript
// ❌ WRONG (performance)
Logger.info('Order ' + orderID + ' processed');
```

**Fix**:
```javascript
// ✓ CORRECT (uses placeholders)
Logger.info('Order {0} processed', orderID);
```

---

## Detection Patterns

### Grep Patterns for Anti-Patterns

```bash
# pdict override
grep -n "pdict\.\(product\|basket\|order\|customer\)\s*=" */

# pdict delete
grep -n "delete\s\+pdict\." */

# Session dependency
grep -n "session\.\(custom\|customer\|privacy\)" */

# eval usage
grep -n "eval\s*(" */

# Transaction in loop
grep -B5 "Transaction\.\(wrap\|begin\)" */ | grep -E "forEach|for\s*\("

# Magic numbers (2+ digits)
grep -n "[^a-zA-Z0-9_]\([0-9]\{2,\}\)[^a-zA-Z0-9_]" */

# ISML cache tag (2024+)
grep -rn "<iscache" --include="*.isml" */

# Cache key pollution - position parameter
grep -n "URLUtils\.url.*position" */

# Search result post-processing
grep -B3 -A3 "\.forEach" */ | grep -E "variations|searchResults"

# Include without iscontent
grep -L "<iscontent" --include="*.isml" */

# CSP unsafe directives
grep -n "unsafe-inline\|unsafe-eval" cartridges/*/cartridge/config/*.json

# Storefront Toolkit dependency (deprecated 25.7)
grep -rn "StorefrontToolkit\|isStorefrontToolkitEnabled" */

# OCAPI leading zero version (rejected 26.2)
grep -rn "v0[0-9]\+_[0-9]\+" */

# Legacy Pipelet (deprecated — 要リリースノート確認)
grep -rn "dw\.system\.Pipelet\|PipeletExecution" */
```
