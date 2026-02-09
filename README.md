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

Static visualization of SFRA dynamic module resolution (`require('*/...')`, `module.superModule`, `server.append/prepend/replace`) with AI-powered interactive exploration.

| Trigger | Description |
|---------|-------------|
| `SFRA explore`, `resolution map` | English triggers |
| `SFRA 探索`, `解決マップ` | Japanese triggers |

**Usage**:

```
/sfra-explore                                    # Generate Resolution Map
/sfra-explore Cart-AddProduct の実行フローは？      # Interactive exploration
```

**Query categories**:
- Route Tracing / Override Analysis / Chain Tracing
- Impact Analysis / Hook Investigation
- Template Tracing / Dependency Mapping

## Requirements

- Claude Code CLI
- An SFRA-based project in the working directory

## License

MIT License
