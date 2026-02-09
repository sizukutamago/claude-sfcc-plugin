# sfcc-plugin

Salesforce Commerce Cloud (SFCC) development toolkit for Claude Code — SFRA code review with parallel swarm agents and interactive module resolution explorer.

Claude Code プラグイン - SFRA コードレビューと動的モジュール解決の可視化・探索を提供します。

## Installation

### From Marketplace

```bash
/plugin install sfcc-plugin@claude-plugin-directory
```

### From GitHub

```bash
/plugin install sizukutamago/claude-sfcc-plugin
```

### Local Development

```bash
claude --plugin-dir /path/to/sfcc-plugin
```

## Skills

### SFRA Review (`/sfra-review`)

Comprehensive SFRA code review using a Swarm pattern with 6 Explorer + 4 Reviewer agents running in parallel.

| Trigger | Description |
|---------|-------------|
| `SFRA review`, `SFCC code review` | English triggers |
| `SFRA レビュー`, `コードレビュー` | Japanese triggers |

**Review targets**: Controller / Model / ISML / Service / Jobs / Client JS

**Checks**:
- Best practices compliance
- Security (CSRF / XSS / injection)
- Performance (N+1 / cache / require in loops)
- Anti-pattern detection
- SCAPI compatibility

### SFRA Explorer (`/sfra-explore`)

Interactive SFRA codebase investigation and exploration. Supports direct code investigation with or without a pre-generated Resolution Map.

| Trigger | Description |
|---------|-------------|
| `SFRA explore`, `SFRA investigate` | English triggers |
| `SFRA 探索`, `SFRA 調査`, `コード調査`, `コード探索` | Japanese triggers |

**Usage**:

```
/sfra-explore Cart-AddProduct の実行フローは？      # Direct investigation (Mode A)
/sfra-explore 商品価格はどこで計算される？           # Business logic investigation
/sfra-explore（マップ生成を指示）                    # Knowledge Base generation (Mode B)
```

**Query categories**:
- Route Tracing / Override Analysis / Chain Tracing
- Impact Analysis / Hook Investigation
- Template Tracing / Dependency Mapping
- Business Logic / Data Flow / Code Pattern

## Requirements

- Claude Code CLI
- An SFRA-based project in the working directory

## License

MIT License
