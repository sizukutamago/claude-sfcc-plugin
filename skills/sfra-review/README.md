# SFRA Review Skill

Salesforce Commerce Cloud (SFCC) / Storefront Reference Architecture (SFRA) のコードベストプラクティスレビュースキル。

## 概要

このスキルは、SFRA コードベースを包括的にレビューし、セキュリティ、パフォーマンス、アーキテクチャ、ベストプラクティスの観点から問題を検出します。

## 対象範囲

- **対象**: SFRA Storefront + Jobs
  - app_storefront_base + overlay cartridges
  - Controllers, Models, ISML, Client-side JS
  - Jobs（バッチ処理）

- **対象外**: Headless/SCAPI/PWA Kit（別スキルで対応予定）

## 使用方法

```bash
# プロジェクトルートで実行
/sfra-review
```

または Claude Code に直接依頼:

```
SFRA のコードレビューを実行して
```

## 出力

レビュー完了後、以下のファイルが生成されます:

```
docs/review/
├── sfra-review.md          # 最終レポート
└── .work/                   # 中間成果物
    ├── 00_scope.json
    ├── 01_index.md
    ├── 02_explorer_*.md
    ├── 03_explorer_unified.md
    ├── 04_review_*.md
    └── 05_review_unified.md
```

## アーキテクチャ

### Phase 構成

```
Phase 0: Scope Detection
    │ Cartridge 構成、Sites/Locales 検出
    ▼
Phase 1: Indexer
    │ Controllers/Routes, ISML, Services 等の "地図" 作成
    ▼
Phase 2: Explorer Swarm (7 agents 並列)
    │ controller, model, isml, client, service, cartridge, jobs
    ▼
Aggregator: Two-step Reduce
    │ JSON 正規化 → 矛盾解消
    ▼
Phase 3: Reviewer Swarm (4 agents 並列)
    │ performance, security, bestpractice, antipattern
    ▼
Aggregator + Gate Decision
    │ P0/P1/P2 判定
    ▼
Phase 4: Reporter
    │ 最終レポート生成
    ▼
docs/review/sfra-review.md
```

### Agent 一覧

#### Explorer Agents (Phase 2)

| Agent | Model | 担当 |
|-------|-------|------|
| explorer-controller | sonnet | Controllers, Routes, Middleware |
| explorer-model | opus | Models, Decorators, Transactions |
| explorer-isml | sonnet | Templates, Resource Bundles |
| explorer-client | sonnet | Client-side JavaScript |
| explorer-service | opus | Services, External Integrations |
| explorer-cartridge | sonnet | Cartridge Architecture |
| explorer-jobs | sonnet | Jobs, Batch Processing |

#### Reviewer Agents (Phase 3)

| Agent | Model | 担当 |
|-------|-------|------|
| reviewer-performance | haiku | Performance Cross-cutting |
| reviewer-security | opus | Security Cross-cutting |
| reviewer-bestpractice | haiku | SFRA Guidelines |
| reviewer-antipattern | haiku | Anti-pattern Detection |

## 判定基準

### P0 (Blocker) - 1つで FAIL

| Category | Example |
|----------|---------|
| Security | XSS (`encoding="off"`), PII ログ出力, eval() 使用 |
| Transaction | Transaction 境界外の書き込み, ループ内 Transaction |
| Architecture | app_storefront_base 直接編集 |
| Performance | グローバル require が 10 以上 |
| Anti-Pattern | pdict override/delete |

### P1 (Major) - 2つ以上で FAIL

| Category | Example |
|----------|---------|
| Controller | server.append() + setViewData() (double execution) |
| ISML | isscript 5 ブロック以上, ハードコード文字列 |
| Service | タイムアウト/リトライ未設定 |
| Cartridge | Naming collision, Circular dependency |
| Jobs | 非冪等, エラー時全体停止 |

### P2 (Minor) - バックログ

| Category | Example |
|----------|---------|
| Performance | キャッシュ未活用 |
| Code Quality | Magic numbers, コード重複 |
| Logging | 文字列連結, 不適切なログレベル |

## ファイル構成

```
sfra-review/
├── SKILL.md                    # Orchestrator (v1.1.0)
├── README.md                   # このファイル
├── agents/
│   ├── indexer.md              # Phase 1
│   ├── aggregator.md           # Swarm 統合
│   ├── reporter.md             # Phase 4
│   └── swarm/
│       ├── explorer-*.md       # Phase 2 (7 files)
│       └── reviewer-*.md       # Phase 3 (4 files)
├── references/
│   ├── handoff_schema.md       # Agent 間通信スキーマ
│   ├── review_rules.md         # P0/P1/P2 判定基準
│   ├── sfra_best_practices.md  # ベストプラクティス + CSP + SCAPI
│   ├── antipatterns.md         # アンチパターンカタログ
│   └── scapi_migration_checklist.md  # SCAPI 移行チェックリスト
├── templates/
│   └── review-report-template.md
├── hooks/                      # 出力バリデーション
│   ├── hooks.json
│   └── validate-output.sh
└── tests/                      # テストフィクスチャ
    ├── fixtures/
    └── expected/
```

## 参考資料

- [SFRA Features and Components](https://developer.salesforce.com/docs/commerce/sfra/guide/b2c-sfra-features-and-comps.html)
- [Customize SFRA](https://developer.salesforce.com/docs/commerce/sfra/guide/b2c-customizing-sfra.html)
- [SFRA Testing](https://developer.salesforce.com/docs/commerce/sfra/guide/b2c-testing-sfra.html)
- [Caching Strategies](https://developer.salesforce.com/docs/commerce/commerce-solutions/guide/caching-strategies-sk.html)

## バージョン

- v1.1.0 - PCI DSS v4.0, CSP, SRI, SCAPI 移行, 廃止機能検出, パフォーマンス強化
- v1.0.0 - 初期リリース
