# SCAPI Migration Readiness Checklist

SFRA プロジェクトの SCAPI/Composable 移行準備度を評価するためのチェックリスト。

## 概要

SCAPI (Shopper Commerce API) は SFCC の新しい API 標準。OCAPI はメンテナンスモード。
新プロジェクトの 70%+ が SCAPI を採用（2025年時点）。

## 移行阻害要因

### P1: Session 直接依存

**検出パターン**:
```
session\.customer
session\.custom\.
session\.privacy\.
session\.forms\.
dw\.system\.Session
request\.session
```

**影響**: SCAPI はステートレス。サーバーサイドセッションに依存するコードは移行不可。

**移行方法**:
```javascript
// Before: Session-dependent
var customerId = session.customer.ID;

// After: Token-based (SLAS)
var customerId = req.currentCustomer.ID;
// Or: SLAS JWT token
```

### P2: OCAPI 直接呼び出し

**検出パターン**:
```
/dw/shop/v\d+
/dw/data/v\d+
/s/-/dw/
OCAPI
```

**影響**: OCAPI エンドポイントは SCAPI に置き換えが必要。

### P2: SLAS 未対応パターン

**検出パターン**:
```javascript
CustomerMgr\.loginCustomer
CustomerMgr\.authenticateCustomer
// 従来の login フローで SLAS トークンを使用していない
```

**影響**: SLAS (Shopper Login and API Access Service) は OAuth 2.1 ベースの認証。

### P2: サーバーサイドレンダリング強依存

**検出パターン**:
```javascript
// ISML から直接 DB 参照（Headless では不可）
ProductMgr\.getProduct
CatalogMgr\.getCategory
// テンプレート内の重い処理
<isscript>[\s\S]*?ProductSearchModel[\s\S]*?</isscript>
```

## Migration Score

| Score | 意味 |
|-------|------|
| 0 P1 + 0-2 P2 | 移行容易 |
| 0 P1 + 3+ P2 | 移行可能（リファクタ要） |
| 1+ P1 | 移行困難（大幅改修必要） |

## Sources

- [SCAPI vs OCAPI 2025](https://www.64labs.com/articles/scapi-vs-ocapi-which-salesforce-commerce-api-really-matters-for-2025)
- [SCAPI Documentation](https://developer.salesforce.com/docs/commerce/commerce-api/guide/why-use-scapi.html)
- [SLAS in SFRA](https://www.rhino-inquisitor.com/slas-in-sfra-or-sitegenesis/)
