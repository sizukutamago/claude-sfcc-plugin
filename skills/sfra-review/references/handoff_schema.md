# Handoff Schema

エージェント間通信のための標準スキーマ定義。

## 基本構造

```yaml
kind: indexer | explorer | reviewer | aggregator | reporter
agent_id: sfra:{type}[:{subtype}]
status: ok | needs_input | blocked
artifacts:
  - path: string  # 出力ファイルパス
    type: string  # index | finding | review | unified | report
findings:
  p0_issues: []
  p1_issues: []
  p2_issues: []
summary: {}  # エージェント固有のサマリー
open_questions: []
blockers: []
next: string  # 次のフェーズ
```

## agent_id 命名規則

| Type | Format | Example |
|------|--------|---------|
| Indexer | `sfra:indexer` | `sfra:indexer` |
| Explorer | `sfra:explorer:{subtype}` | `sfra:explorer:controller` |
| Reviewer | `sfra:reviewer:{subtype}` | `sfra:reviewer:security` |
| Aggregator | `sfra:aggregator:{phase}` | `sfra:aggregator:explorer` |
| Reporter | `sfra:reporter` | `sfra:reporter` |

## Issue スキーマ

```yaml
issue:
  id: string          # "CTRL-001", "SEC-P0-001"
  category: string    # "double_execution", "xss"
  file: string        # 対象ファイルパス
  line: number        # 行番号（オプション）
  code: string        # 問題のコードスニペット（オプション）
  description: string # 問題の説明
  risk: string        # リスクの説明（オプション）
  impact: string      # 影響範囲（オプション）
  fix: string         # 修正方法
  compliance: []      # 関連するコンプライアンス（OWASP, PCI 等）
```

## Status 定義

| Status | 意味 | 次のアクション |
|--------|------|----------------|
| `ok` | 正常完了 | 次のフェーズへ |
| `needs_input` | 追加情報が必要 | ユーザーに確認 |
| `blocked` | 続行不能 | エラー報告、リトライ検討 |

## Phase 間のフロー

```
Phase 0 (Scope)
    │
    ▼
Phase 1 (Indexer)
    │ status: ok
    ▼
Phase 2 (Explorer Swarm)
    │ 7 agents parallel
    │ all status: ok
    ▼
Aggregator (Explorer)
    │ status: ok
    ▼
Phase 3 (Reviewer Swarm)
    │ 4 agents parallel
    │ all status: ok
    ▼
Aggregator (Reviewer) + Gate
    │ status: ok
    ▼
Phase 4 (Reporter)
    │ status: ok
    ▼
Done
```
