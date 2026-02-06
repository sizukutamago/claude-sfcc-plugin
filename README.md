# sfcc-plugin

Claude Code プラグイン - Salesforce Commerce Cloud (SFCC) 開発ツール集

SFRA コードレビューと動的モジュール解決の可視化・探索を提供します。

## インストール

### ローカル開発

```bash
claude --plugin-dir /path/to/sfcc-plugin
```

## スキル一覧

### SFRA レビュー

| スキル | 説明 | トリガー例 |
|--------|------|-----------|
| sfra-review | SFRA コードレビュー（Swarm パターン） | 「SFRA review」「SFRA レビュー」 |

Swarm パターンで Explorer×6 + Reviewer×4 を並列実行し、Controller / Model / ISML / Service / Jobs / Client JS を包括レビュー。

**チェック項目**:
- ベストプラクティス準拠
- セキュリティ（CSRF / XSS / インジェクション）
- パフォーマンス（N+1 / キャッシュ / ループ内 require）
- アンチパターン検出
- SCAPI 互換性

### SFRA Explorer

| スキル | 説明 | トリガー例 |
|--------|------|-----------|
| sfra-explorer | SFRA 解決マップ生成 + インタラクティブ探索 | 「SFRA explore」「SFRA 探索」 |

SFRA の動的モジュール解決（`require('*/...')`、`module.superModule`、`server.append/prepend/replace`）を静的に可視化する Resolution Map を生成し、AI によるインタラクティブ探索を支援。

**使い方**:

```
/sfra-explore                              # Resolution Map 生成
/sfra-explore Cart-AddProduct の実行フローは？  # インタラクティブ探索
```

**対応する質問カテゴリ**:
- Route Tracing / Override Analysis / Chain Tracing
- Impact Analysis / Hook Investigation
- Template Tracing / Dependency Mapping

## ライセンス

MIT License
