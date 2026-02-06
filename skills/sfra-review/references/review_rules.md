# Review Rules

P0/P1/P2 判定基準の詳細定義。

## 重大度定義

| Severity | 名前 | 意味 | Gate 閾値 |
|----------|------|------|----------|
| **P0** | Blocker | 即時修正必須、リリースブロッカー | 1つで FAIL |
| **P1** | Major | 高優先度、2週間以内に修正 | 2つ以上で FAIL |
| **P2** | Minor | バックログ、計画的に修正 | 閾値なし |

## P0 (Blocker) 条件

### Security

| Condition | Example |
|-----------|---------|
| XSS 脆弱性 | `encoding="off"` の使用 |
| PII ログ出力 | クレジットカード、メール、電話、住所、IP 等のログ |
| ハードコード認証情報 | API キー、パスワードの埋め込み |
| CSRF 未対策 | 重要操作に CSRF トークンなし |
| Injection | 動的コード実行、SQL 連結 |
| PCI v4.0 Req 6.4.3 違反 | 支払いページの SRI 未設定外部スクリプト |
| PCI v4.0 Req 6.4.3 違反 | 支払いページのインラインスクリプト |
| PCI v4.0 Req 3.4.2 違反 | PAN データの非暗号化転送/ログ出力 |
| CSP `unsafe-inline`（支払いページ影響） | httpHeadersConf.json に `unsafe-inline` かつ支払いページに影響 |
| CSP `unsafe-eval`（支払いページ影響） | httpHeadersConf.json に動的コード実行許可 かつ支払いページに影響 |

### Transaction

| Condition | Example |
|-----------|---------|
| 境界外書き込み | Transaction なしでの `custom` 更新 |
| ループ内 Transaction | `forEach` 内で `Transaction.wrap()` |

### Architecture

| Condition | Example |
|-----------|---------|
| Base 直接編集 | `app_storefront_base` ファイルの変更 |

### Performance

| Condition | Example |
|-----------|---------|
| 過剰グローバル require | 単一ファイルで 10 以上 |

### Anti-Pattern

| Condition | Example |
|-----------|---------|
| pdict override | `pdict.product = customProduct` |
| pdict delete | `delete pdict.recommendations` |

## P1 (Major) 条件

### Controller

| Condition | Example |
|-----------|---------|
| Double execution risk | `server.append()` + `setViewData()` |
| Missing next() | Middleware で `next()` 未呼び出し |

### ISML

| Condition | Example |
|-----------|---------|
| Excessive isscript | 5 ブロック以上の `<isscript>` |
| Hardcoded text | 外部化されていない文字列 |
| Remote include >20 | ページあたり 20 超の remote include |

### Service

| Condition | Example |
|-----------|---------|
| Missing timeout | `setTimeout()` 未設定 |
| Missing retry | リトライロジックなし |
| Missing error handling | `result.status` チェックなし |

### Cartridge

| Condition | Example |
|-----------|---------|
| Naming collision | 複数 cartridge に同名ファイル |
| Circular dependency | 相互 require |

### Jobs

| Condition | Example |
|-----------|---------|
| Not idempotent | 再実行で重複データ |
| No error continuation | 1件エラーで全体停止 |

### Security (2025+)

| Condition | Example |
|-----------|---------|
| PCI v4.0 Req 11.6.1 | 支払いページの改ざん検知メカニズム未設定 |
| CSP `unsafe-inline` / `unsafe-eval`（非支払いページ） | 支払いページ影響が不明または限定的な場合 |
| CSP レポーティング未設定 | `report-uri` / `report-to` なし |
| httpHeadersConf.json 未設定 | セキュリティヘッダー設定ファイル欠如 |
| SRI 未設定（非支払いページ） | 外部リソースに `integrity` 属性なし |
| エンコーディングコンテキスト不一致 | `jshtml`/`json` エンコーディング未使用 |

### Best Practice

| Condition | Example |
|-----------|---------|
| Extend vs Replace | 不適切な選択 |
| Missing decorator | `module.superModule` 未使用 |

### Anti-Pattern

| Condition | Example |
|-----------|---------|
| Session dependency | `session.custom` 使用 |
| God object | 1000 行以上のファイル |
| 廃止機能使用 | Storefront Toolkit (25.7), OCAPI 先行ゼロ (26.2), レガシー Pipelet（各バージョン要確認） |

### Performance

| Condition | Example |
|-----------|---------|
| スクリプト実行時間リスク | 3重ネストループ、不明確な while 条件 |

### Caching (2024+)

| Condition | Example |
|-----------|---------|
| ISML cache tag | `<iscache>` の使用（Response#setExpires 推奨） |
| Cache key pollution | 不要な URL パラメータ（position, timestamp 等） |
| Include content-type mismatch | include 側で `<iscontent>` 未設定 |

## P2 (Minor) 条件

### Performance

| Condition | Example |
|-----------|---------|
| Suboptimal cache TTL | 短すぎ/長すぎ |
| Missing cache | キャッシュ可能なのに未使用 |
| Search post-processing | 検索結果の後処理、variation 反復 |

### Code Quality

| Condition | Example |
|-----------|---------|
| Magic numbers | ハードコード数値 |
| Copy-paste code | コード重複 |
| Inconsistent naming | 命名規則違反 |

### Logging

| Condition | Example |
|-----------|---------|
| String concatenation | `Logger.info('x' + y)` |
| Wrong log level | DEBUG に重要情報 |

### CSP

| Condition | Example |
|-----------|---------|
| upgrade-insecure-requests 未設定 | HTTP 混在コンテンツリスク |

## Gate 判定ロジック

```javascript
function gateDecision(p0Count, p1Count) {
    if (p0Count >= 1) {
        return {
            result: 'FAIL',
            reason: 'P0 (Blocker) issues found',
            immediateAction: true
        };
    }

    if (p1Count >= 2) {
        return {
            result: 'FAIL',
            reason: 'Multiple P1 (Major) issues',
            immediateAction: false
        };
    }

    if (p1Count === 1) {
        return {
            result: 'PASS',
            reason: 'Single P1, review recommended',
            immediateAction: false
        };
    }

    return {
        result: 'PASS',
        reason: 'All clear',
        immediateAction: false
    };
}
```

## 例外ルール

### P0 から P1 への降格

以下の条件で P0 を P1 に降格可能:

1. **明確な緩和策がある**: 他のレイヤーで保護されている
2. **影響範囲が限定的**: 内部ツールのみ、非公開 API
3. **一時的な対応**: 緊急リリースで後日修正予定（文書化必須）

### P1 から P2 への降格

1. **レガシーコード**: 今回の変更範囲外
2. **計画済み改修**: 別チケットで対応予定
