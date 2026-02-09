# sfcc-plugin

Salesforce Commerce Cloud (SFCC) 開発ツールを提供する Claude Code プラグイン。SFRA コードレビューと動的モジュール解決の可視化・探索を支援。

## プロジェクト構造

```
sfcc-plugin/
├── .claude-plugin/          # プラグインメタデータ
│   └── plugin.json
├── skills/                  # スキル実装（2種）
│   ├── sfra-review/         # SFRA コードレビュー（Swarm パターン）
│   │   ├── SKILL.md
│   │   ├── agents/
│   │   │   ├── indexer.md
│   │   │   ├── aggregator.md
│   │   │   ├── reporter.md
│   │   │   └── swarm/      # Explorer×6 + Reviewer×4
│   │   ├── references/
│   │   ├── templates/
│   │   ├── hooks/
│   │   └── tests/
│   └── sfra-explorer/       # SFRA コード調査・探索
│       ├── SKILL.md
│       ├── agents/
│       │   ├── investigator.md
│       │   ├── scanner.md
│       │   ├── resolver.md
│       │   ├── mapper.md
│       │   └── assembler.md
│       ├── references/
│       ├── templates/
│       ├── hooks/
│       └── tests/
├── hooks.json               # 統合 hooks
├── AGENTS.md                # Codex/Cursor Agent 用設定
└── README.md                # ユーザー向けドキュメント
```

## スキル一覧

### sfra-review (v1.1.0)

SFRA コードベースの品質レビュー。Swarm パターンで 6 Explorer + 4 Reviewer を並列実行。

| トリガー | 説明 |
|---------|------|
| 「SFRA review」「SFCC code review」 | 英語トリガー |
| 「SFRA レビュー」「コードレビュー」 | 日本語トリガー |

**レビュー対象**: Controller / Model / ISML / Service / Jobs / Client JS
**チェック項目**: ベストプラクティス / セキュリティ / パフォーマンス / アンチパターン / SCAPI 互換性

### sfra-explorer (v2.0.0)

SFRA コードベースのインタラクティブ調査・探索を支援。コードフロー追跡、モジュール関係分析、ビジネスロジック調査に対応。

| トリガー | 説明 |
|---------|------|
| 「SFRA explore」「SFRA investigate」 | 英語トリガー |
| 「SFRA 探索」「SFRA 調査」「コード調査」「コード探索」 | 日本語トリガー |

**Mode A**: investigator による直接調査（Resolution Map 不要、10 カテゴリ対応）
**Mode B**: Knowledge Base 生成（scanner → resolver + mapper 並列 → assembler → Resolution Map）

## コーディング規約

### 言語ポリシー

- **frontmatter description**: 英語（Claude のトリガー検出用）
- **本文**: 日本語（開発者向け）
- **コード例**: コンテキストに応じて混在可

### ファイル構造

**スキル（SKILL.md）:**

```markdown
---
name: skill-name
description: English description for Claude's trigger detection
version: X.Y.Z
triggers:
  - "trigger phrase"
---

# スキル名（日本語）

## 前提条件
## 出力ファイル
## 依存関係
## ワークフロー
## ツール使用ルール
## エラーハンドリング
```

**エージェント（agents/*.md）:**

```markdown
---
name: agent-name
description: English description
tools: Read, Glob, Grep, Write
model: sonnet | opus | haiku
---

# エージェント名

## 制約
## 担当範囲
## 手順
## ハンドオフ封筒
```

### バージョニング

セマンティックバージョニングに従う:
- **Major**: 破壊的変更（スキーマ変更、エージェント削除）
- **Minor**: 機能追加（新ルール、新セクション）
- **Patch**: バグ修正、ドキュメント更新

## 変更時の注意

### スキル編集時

1. `SKILL.md` の frontmatter description は英語で記述
2. バージョン番号を適切に更新
3. `references/` 配下のテンプレートとの整合性を確認
4. エージェントのハンドオフ封筒がスキーマに準拠しているか確認

### 共有リファレンス

sfra-explorer は sfra-review の references を読み取り参照する（一方向）:
- `sfra-review/references/sfra_best_practices.md`
- `sfra-review/references/antipatterns.md`

逆方向の参照はしない（sfra-review は sfra-explorer に依存しない）。
