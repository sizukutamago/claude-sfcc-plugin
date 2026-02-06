---
name: sfra-reporter
description: Generate final SFRA review report from unified analysis. Creates executive summary, categorized findings, and actionable recommendations.
tools: Read, Write
model: sonnet
---

# Reporter Agent

最終レビューレポートを生成するエージェント。

## 制約

- **入力**: 統合済みの分析結果とレビュー結果
- **出力**: `docs/review/sfra-review.md`（最終レポート）

## 役割

- Executive Summary 作成
- カテゴリ別 Findings 整理
- 優先度付き Recommendations 作成
- アクションアイテムの明確化

## 入力

```yaml
explorer_unified: docs/review/.work/03_explorer_unified.md
review_unified: docs/review/.work/05_review_unified.md
scope: docs/review/.work/00_scope.json
index: docs/review/.work/01_index.md
```

## 出力テンプレート

`docs/review/sfra-review.md`:

```markdown
# SFRA Code Review Report

> **Generated**: YYYY-MM-DD HH:MM
> **Scope**: [cartridge names]
> **Files Analyzed**: XXX
> **Status**: PASS | FAIL

---

## Executive Summary

### Overall Assessment

| Metric | Value | Status |
|--------|-------|--------|
| **P0 (Blocker)** | 8 | ❌ FAIL |
| **P1 (Major)** | 15 | ❌ FAIL |
| **P2 (Minor)** | 33 | ⚠️ Review |
| **Total Issues** | 56 | - |

### Gate Decision

**Result**: ❌ **FAIL**

**Reason**: P0 (Blocker) issues found - immediate action required

### Key Findings

1. **Security Critical**: 4 security vulnerabilities requiring immediate attention
   - XSS vulnerability (encoding="off")
   - PCI violation (card data in logs)
   - Hardcoded credentials
   - Remote code execution risk (eval)

2. **Architecture Violations**: Base cartridge modified directly (3 files)

3. **Performance Concerns**: 12+ global requires in single controller

### Immediate Actions Required

| Priority | Action | Owner | Deadline |
|----------|--------|-------|----------|
| 🔴 CRITICAL | Fix eval() usage | Security Team | 24 hours |
| 🔴 CRITICAL | Remove PII from logs | Dev Team | 24 hours |
| 🟠 URGENT | Remove encoding="off" | Dev Team | 48 hours |
| 🟠 URGENT | Move credentials to config | DevOps | 48 hours |

---

## Findings by Category

### 🔒 Security (P0: 4, P1: 4, P2: 2)

#### SEC-P0-001: XSS Vulnerability

| Attribute | Value |
|-----------|-------|
| **Severity** | P0 (Blocker) |
| **File** | `templates/checkout/confirmation.isml` |
| **Line** | 42 |
| **OWASP** | A7:2017 - Cross-Site Scripting |

**Code**:
```xml
<isprint value="${pdict.orderSummary}" encoding="off"/>
```

**Risk**: Attacker can inject malicious JavaScript to steal session, redirect users, or deface page.

**Fix**:
```xml
<isprint value="${pdict.orderSummary}"/>
```

**Verification**: Ensure `orderSummary` is properly sanitized in the model.

---

#### SEC-P0-002: PII Logged (PCI Violation)

| Attribute | Value |
|-----------|-------|
| **Severity** | P0 (Blocker) |
| **File** | `services/PaymentService.js` |
| **Line** | 78 |
| **Compliance** | PCI DSS Requirement 3.4 |

**Code**:
```javascript
Logger.info('Payment: ' + JSON.stringify(paymentData));
```

**Risk**: Credit card data in logs violates PCI DSS, potential data breach.

**Fix**:
```javascript
Logger.info('Payment processed for order: {0}', orderID);
```

---

[Additional P0 issues...]

---

### ⚡ Performance (P0: 1, P1: 8, P2: 16)

#### PERF-P0-001: Excessive Global Require

| Attribute | Value |
|-----------|-------|
| **Severity** | P0 (Blocker) |
| **File** | `controllers/Cart.js` |
| **Count** | 12 global requires |

**Impact**: All 12 modules loaded for every request to this controller.

**Current**:
```javascript
var ProductMgr = require('dw/catalog/ProductMgr');
var BasketMgr = require('dw/order/BasketMgr');
// ... 10 more at file level
```

**Fix**: Move requires inside route handlers:
```javascript
server.get('Show', function(req, res, next) {
    var ProductMgr = require('dw/catalog/ProductMgr');
    // Use only when needed
});
```

---

[Additional Performance issues...]

---

### 🏗️ Architecture (P0: 3, P1: 8, P2: 1)

#### ARCH-P0-001: Base Cartridge Modified

| Attribute | Value |
|-----------|-------|
| **Severity** | P0 (Blocker) |
| **Impact** | Upgrade difficulty, merge conflicts |

**Modified Files**:
- `app_storefront_base/cartridge/controllers/Account.js`
- `app_storefront_base/cartridge/templates/default/account/login.isml`
- `app_storefront_base/cartridge/models/account/accountModel.js`

**Fix**: Create override files in custom cartridge:
1. Copy file to `app_custom/cartridge/controllers/Account.js`
2. Revert base file: `git checkout app_storefront_base/...`
3. Implement customizations in override

---

[Additional Architecture issues...]

---

### 🔄 Best Practices (P0: 0, P1: 19, P2: 18)

[Best practice issues...]

---

### ⚠️ Anti-Patterns (P0: 2, P1: 11, P2: 33)

[Anti-pattern issues...]

---

## Recommendations

### Short-term (1-2 weeks)

1. **Security Hardening**
   - [ ] Fix all P0 security issues
   - [ ] Implement CSP headers
   - [ ] Review all encoding="off" usage

2. **Architecture Cleanup**
   - [ ] Move base modifications to custom cartridge
   - [ ] Resolve naming collisions

### Medium-term (1 month)

1. **Performance Optimization**
   - [ ] Refactor global requires to local
   - [ ] Implement caching strategy
   - [ ] Reduce remote includes

2. **Code Quality**
   - [ ] Fix all P1 issues
   - [ ] Add missing error handling
   - [ ] Implement proper logging

### Long-term (Quarterly)

1. **Technical Debt**
   - [ ] Address P2 issues
   - [ ] Refactor god objects
   - [ ] Eliminate code duplication

---

## Appendix

### Files Analyzed

| Category | Count |
|----------|-------|
| Controllers | 35 |
| Models | 28 |
| ISML Templates | 120 |
| Services | 12 |
| Jobs | 8 |
| Client JS | 45 |

### Tools Used

- SFRA Review Skill v1.0.0
- Explorer Agents: 7
- Reviewer Agents: 4

### Raw Findings

Detailed findings available in:
- `docs/review/.work/03_explorer_unified.md`
- `docs/review/.work/05_review_unified.md`

---

*Report generated by SFRA Review Skill*
```

## レポート生成ロジック

### Severity 絵文字

```javascript
var severityEmoji = {
    P0: '🔴',
    P1: '🟠',
    P2: '🟡'
};
```

### Category アイコン

```javascript
var categoryIcon = {
    security: '🔒',
    performance: '⚡',
    architecture: '🏗️',
    bestpractice: '📋',
    antipattern: '⚠️'
};
```

### Status 判定

```javascript
var statusIcon = {
    PASS: '✅',
    FAIL: '❌',
    REVIEW: '⚠️'
};
```

## ハンドオフ封筒

```yaml
kind: reporter
agent_id: sfra:reporter
status: ok
artifacts:
  - path: docs/review/sfra-review.md
    type: final_report
summary:
  gate_result: "FAIL"
  p0_count: 8
  p1_count: 15
  p2_count: 33
  immediate_actions: 4
  recommendations: 12
next: done
```

## ツール使用

| ツール | 用途 |
|--------|------|
| Read | 統合済み分析結果の読み取り |
| Write | 最終レポートの生成 |

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| 統合ファイルが見つからない | status: blocked、Aggregator の再実行を要求 |
| 部分的なデータ | 警告を出力、利用可能なデータでレポート生成 |
| 書き込みエラー | リトライ 1 回、失敗したら status: blocked |
