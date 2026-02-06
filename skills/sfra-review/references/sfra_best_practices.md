# SFRA Best Practices Reference

公式ガイドラインとコミュニティベストプラクティスの参照資料。

## Controller Best Practices

### Middleware Chain

```javascript
// ✓ CORRECT: Proper middleware usage
server.prepend('Show', function(req, res, next) {
    // Pre-processing (runs first)
    next();
});

server.append('Show', function(req, res, next) {
    // Post-processing (runs after base)
    // WARNING: Don't modify ViewData here!
    next();
});

// ✓ CORRECT: Use replace for ViewData changes
server.replace('Show', function(req, res, next) {
    var viewData = res.getViewData();
    viewData.customField = 'value';
    res.setViewData(viewData);
    next();
});
```

### Require Scope

```javascript
// ✓ CORRECT: Local require
server.get('Show', function(req, res, next) {
    var ProductMgr = require('dw/catalog/ProductMgr');
    var product = ProductMgr.getProduct(req.querystring.pid);
    // ...
    next();
});

// ❌ WRONG: Global require
var ProductMgr = require('dw/catalog/ProductMgr');  // Loaded for ALL routes!
```

## Model Best Practices

### Decorator Pattern

```javascript
'use strict';

var base = module.superModule;

function ProductModel(product, config) {
    base.call(this, product, config);

    // Custom properties
    this.customField = product.custom.myField;
}

ProductModel.prototype = Object.create(base.prototype);
module.exports = ProductModel;
```

### Transaction Handling

```javascript
var Transaction = require('dw/system/Transaction');

// ✓ CORRECT: Read outside, write inside
var product = ProductMgr.getProduct(productID);
var newValue = calculateValue(product);

try {
    Transaction.wrap(function() {
        product.custom.field = newValue;
    });
} catch (e) {
    Logger.error('Transaction failed: {0}', e.message);
    throw e;
}
```

## ISML Best Practices

### Text Externalization

```xml
<!-- ✓ CORRECT: Use resource bundles -->
<h1>${Resource.msg('heading.welcome', 'common', null)}</h1>

<!-- ❌ WRONG: Hardcoded text -->
<h1>Welcome to our store</h1>
```

### Minimal isscript

```xml
<!-- ✓ CORRECT: Pass calculated values from model -->
<div class="price">${pdict.formattedPrice}</div>

<!-- ❌ WRONG: Business logic in template -->
<isscript>
    var price = product.price;
    var discount = pdict.promotion.discount;
    var finalPrice = price * (1 - discount);
</isscript>
```

### Encoding

```xml
<!-- ✓ CORRECT: Default encoding (safe) -->
<isprint value="${pdict.userInput}"/>

<!-- ✓ CORRECT: Explicit encoding -->
<isprint value="${pdict.content}" encoding="htmlencode"/>

<!-- ❌ WRONG: No encoding (XSS risk) -->
<isprint value="${pdict.userInput}" encoding="off"/>
```

## Service Best Practices

### Configuration

```javascript
var LocalServiceRegistry = require('dw/svc/LocalServiceRegistry');

var myService = LocalServiceRegistry.createService('my.service', {
    createRequest: function(svc, params) {
        svc.setRequestMethod('POST');
        svc.addHeader('Content-Type', 'application/json');
        svc.client.setTimeout(30000);  // Always set timeout!
        return JSON.stringify(params);
    },
    parseResponse: function(svc, response) {
        return JSON.parse(response.text);
    },
    mockCall: function(svc, params) {
        return {
            statusCode: 200,
            statusMessage: 'OK',
            text: JSON.stringify({ success: true })
        };
    }
});
```

### Error Handling

```javascript
var result = myService.call(params);

if (result.status === 'OK') {
    return result.object;
} else {
    Logger.error('Service failed: {0}', result.errorMessage);
    // Implement fallback or return error
    return { error: true, message: result.errorMessage };
}
```

## Job Best Practices

### Chunk Processing

```javascript
module.exports = {
    chunkSize: 100,

    process: function(products) {
        var errors = [];

        products.forEach(function(product) {
            try {
                processProduct(product);
            } catch (e) {
                errors.push({ id: product.ID, error: e.message });
                Logger.error('Failed: {0}', e.message);
                // Continue processing!
            }
        });

        if (errors.length > 0) {
            Logger.warn('Completed with {0} errors', errors.length);
        }
    }
};
```

### Idempotency

```javascript
function processOrder(order) {
    // Check if already processed
    if (order.custom.processedAt) {
        Logger.info('Order {0} already processed', order.orderNo);
        return;
    }

    // Process
    doProcessing(order);

    // Mark as processed
    Transaction.wrap(function() {
        order.custom.processedAt = new Date();
    });
}
```

## Caching Best Practices (2024+)

### Controller-based Caching

```javascript
// ✓ CORRECT: Use Response#setExpires
server.get('Show', function(req, res, next) {
    // Set cache expiration in controller
    res.setExpires(new Date(Date.now() + 24 * 60 * 60 * 1000));

    // Or use caching helper
    res.cachePeriod = 24;  // hours
    res.cachePeriodUnit = 'hours';

    next();
});

// ❌ WRONG: ISML-based caching (deprecated)
// <iscache type="relative" hour="24"/>
```

### Cache Key Hygiene

```javascript
// ✓ CORRECT: Minimal URL parameters
var productUrl = URLUtils.url('Product-Show', 'pid', productID);

// ❌ WRONG: Unnecessary parameters pollute cache
var productUrl = URLUtils.url('Product-Show',
    'pid', productID,
    'position', index,      // Breaks cache!
    'timestamp', Date.now() // Breaks cache!
);
```

### Search Performance

```javascript
// ✓ CORRECT: Let search engine handle filtering
var searchModel = new ProductSearchModel();
searchModel.setSearchPhrase(query);
searchModel.addRefinementValues('category', categoryID);
searchModel.search();

// ❌ WRONG: Post-processing search results
searchResults.forEach(function(product) {
    // Don't iterate variations here!
    product.variations.forEach(...);
});
```

## Cartridge Best Practices

### Overlay Pattern

```
cartridges/
├── app_storefront_base/     # NEVER MODIFY!
├── app_custom/              # Custom overlay
│   └── cartridge/
│       └── controllers/
│           └── Account.js   # Override of base
└── plugin_wishlists/        # Plugin
```

### Cartridge Path

```
# Correct order: Custom → Plugins → Base
app_custom:plugin_wishlists:int_payment:app_storefront_base
```

## Logging Best Practices

```javascript
var Logger = require('dw/system/Logger');

// Use placeholders (better performance)
Logger.info('Processing order: {0}', orderID);

// Use appropriate levels
Logger.debug('Debug info: {0}', debugData);      // Dev only
Logger.info('Order {0} processed', orderID);     // Normal
Logger.warn('Retry {0} for service', attempt);   // Warning
Logger.error('Failed: {0}', error.message);      // Error

// Never log sensitive data!
// ❌ Logger.info('Card: {0}', cardNumber);
```

## Sources

### Official Documentation
- [SFRA Features and Components](https://developer.salesforce.com/docs/commerce/sfra/guide/b2c-sfra-features-and-comps.html)
- [Customize SFRA](https://developer.salesforce.com/docs/commerce/sfra/guide/b2c-customizing-sfra.html)
- [SFRA Testing](https://developer.salesforce.com/docs/commerce/sfra/guide/b2c-testing-sfra.html)
- [SFRA Modules](https://developer.salesforce.com/docs/commerce/ocapi/guide/b2c-sfra-modules.html)
- [Caching Strategies](https://developer.salesforce.com/docs/commerce/ocapi/guide/caching-strategies-sk.html)
- [B2C Site Performance](https://developer.salesforce.com/docs/commerce/ocapi/guide/b2c-site-performance.html)

### API Reference
- [Transaction Class](https://salesforcecommercecloud.github.io/b2c-dev-doc/docs/current/scriptapi/html/api/class_dw_system_Transaction.html)
- [SFRA JSDoc - Caching Responses](https://salesforcecommercecloud.github.io/b2c-dev-doc/docs/current/sfrajsdoc/js/server/tutorial-CachingResponses.html)
- [isprint Tag](https://developer.salesforce.com/docs/commerce/ocapi/guide/b2c-isprint.html)

### Security
- [Cross-Site Scripting Prevention](https://sfcclearning.com/infocenter/content/b2c_commerce/topics/b2c_security_best_practices/b2c_cross_site_scripting.php)

---

## CSP (Content Security Policy) ベストプラクティス

### 推奨設定

`cartridge/config/httpHeadersConf.json` でセキュリティヘッダーを設定:

```json
{
  "Content-Security-Policy": "default-src 'self'; script-src 'self' 'nonce-{random}'; style-src 'self'; img-src 'self' data:; report-uri /csp-report",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "SAMEORIGIN",
  "X-XSS-Protection": "1; mode=block"
}
```

### 避けるべき設定

- `unsafe-inline`: インラインスクリプトを許可（XSS リスク）
- `unsafe-eval`: 動的コード評価を許可
- `*`（ワイルドカード）: 全ソースを許可

### PCI DSS v4.0 要件

- Req 6.4.3: 支払いページの全スクリプトに SRI (Subresource Integrity) を設定
- Req 11.6.1: スクリプト改ざん検知メカニズムの実装（eCDN Page Shield 推奨）

---

## SCAPI 移行準備ベストプラクティス

### Session 依存の排除

```javascript
// ❌ WRONG: Direct session access
var customerId = session.customer.ID;
session.custom.lastVisit = new Date();

// ✓ CORRECT: Request context
var customerId = req.currentCustomer.ID;
```

### SLAS (Shopper Login and API Access Service) 対応

- OAuth 2.1 ベースの認証フローを使用
- JWT トークンでの認証を推奨
- `CustomerMgr.loginCustomer` から SLAS トークンベースに移行

### OCAPI → SCAPI 移行

- OCAPI エンドポイントの直接参照を SCAPI に置換
- SCAPI はステートレスなため、セッション依存を排除
- 詳細は `references/scapi_migration_checklist.md` を参照
