---
generated_at: "{generated_at}"
git_commit: "{git_commit}"
cartridge_path_source: "{cartridge_path_source}"
cartridge_path_confidence: "{cartridge_path_confidence}"
cartridge_path: "{cartridge_path}"
total_files: {total_files}
total_cartridges: {total_cartridges}
---

# SFRA Resolution Map

<!-- assembler: Replace metadata above with actual values from merged scanner output -->

## Section 1: Cartridge Stack

カートリッジの優先順位と構成。カートリッジパスの左側が最優先で解決される。

| Order | Cartridge | Type | Path | Files |
|-------|-----------|------|------|-------|
<!-- assembler: Insert cartridge stack rows here, sorted by cartridge path order -->
| 1 | {cartridge_name} | {type} | {path} | {file_count} |
| 2 | {cartridge_name} | {type} | {path} | {file_count} |
| 3 | {cartridge_name} | {type} | {path} | {file_count} |

**Type 分類**:
- `base`: app_storefront_base
- `overlay`: app_* (base以外)
- `plugin`: plugin_*
- `integration`: int_*

---

## Section 2: File Resolution Table

各ファイルパスの解決先マッピング。同じ相対パスが複数カートリッジに存在する場合、最優先カートリッジが有効。

| Relative Path | Resolves From | Also In | SuperModule | Line Count |
|---------------|---------------|---------|-------------|------------|
<!-- assembler: Insert file resolution rows here, group by file type (controllers, models, scripts, templates) -->
| {relative_path} | {resolves_from_cartridge} | {shadowed_cartridges} | {super_module_target} | {line_count} |
| {relative_path} | {resolves_from_cartridge} | - | null | {line_count} |

**凡例**:
- **Resolves From**: 実際に使用されるカートリッジ
- **Also In**: シャドウイングされる他カートリッジ（カンマ区切り、存在しない場合は `-`）
- **SuperModule**: `module.superModule` で参照する次のカートリッジ（使用していない場合は `null`）

---

## Section 3: SuperModule Chains

`module.superModule` による継承チェーン。コントローラー拡張パターンの可視化。

| Chain ID | Source | Step 1 | Step 2 | Step 3 | Terminal |
|----------|--------|--------|--------|--------|----------|
<!-- assembler: Insert superModule chain rows here, one row per chain -->
| {chain_id} | {source_cartridge}/{file} | {step1_cartridge}/{file} | {step2_cartridge}/{file} | {step3_cartridge}/{file} | {terminal_cartridge} |
| {chain_id} | {source_cartridge}/{file} | {step1_cartridge}/{file} | null | null | {terminal_cartridge} |

**警告**: チェーン長が5段以上の場合はパフォーマンス影響に注意。

<!-- assembler: Add warning marker ⚠️ for chains with depth >= 5 -->

---

## Section 4: Controller Route Map

### 4.1 Route Definition

各コントローラールートとミドルウェアチェーン。実行順序は `prepend -> base/replace -> append`。

| Route | HTTP Method | Order | Cartridge | Method | File:Line |
|-------|------------|-------|-----------|--------|-----------|
<!-- assembler: Insert route definition rows here, grouped by route name, sorted by execution order -->
| {Controller-Action} | {GET|POST|USE} | 1 | {cartridge} | prepend | {file_path}:{line} |
| {Controller-Action} | {GET|POST|USE} | 2 | {cartridge} | base | {file_path}:{line} |
| {Controller-Action} | {GET|POST|USE} | 3 | {cartridge} | append | {file_path}:{line} |

**Method 分類**:
- `base`: 元の実装
- `prepend`: ルート処理前に実行
- `append`: ルート処理後に実行
- `replace`: 元の実装を置き換え
- `extend`: 新規ルート追加

### 4.2 Event Listeners

ルートイベントリスナーの定義。SFRA ルートライフサイクルフックの可視化。

| Event | Cartridge | File:Line | Action |
|-------|-----------|-----------|--------|
<!-- assembler: Insert event listener rows here -->
| {route:Start|route:Step|route:Redirect|route:BeforeComplete|route:Complete} | {cartridge} | {file_path}:{line} | {action_description} |

---

## Section 5: Template Override Map

ISML テンプレートの上書き関係。同名テンプレートは最優先カートリッジが使用される。

| Template Path | Provided By | Overrides | Includes |
|---------------|-------------|-----------|----------|
<!-- assembler: Insert template override rows here -->
| {template_relative_path} | {cartridge} | {overridden_cartridge} | [{include1}, {include2}] |
| {template_relative_path} | {cartridge} | null | [] |

**凡例**:
- **Provided By**: 実際に使用されるテンプレート提供カートリッジ
- **Overrides**: 上書きされる元カートリッジ（存在しない場合は `null`）
- **Includes**: このテンプレートが `isinclude` する他テンプレート（配列、存在しない場合は `[]`）

---

## Section 6: Hook Registration Map

フック定義と登録状況。**全カートリッジの登録済み Hook が全て実行される**（`require('*/...')` の「最初のマッチのみ」とは異なる）。

| Hook Name | Cartridge | Script | Execution Order | hooks.json Path |
|-----------|-----------|--------|-----------------|-----------------|
<!-- assembler: Insert hook registration rows here -->
| {hook_name} | {cartridge} | {script_path} | {execution_order} | {hooks_json_path} |

**Execution Order**: カートリッジパス左→右の順で全 Hook が実行される。

<!-- assembler: Sort by hook name, then by cartridge path order. All hooks for the same extension point are executed. -->

---

## Section 7: Reverse Dependency Index

各ファイルを参照している他ファイルの逆引きインデックス。影響範囲分析に使用。

| File | Used By | Ref Type |
|------|---------|----------|
<!-- assembler: Insert reverse dependency rows here -->
| {file_path} | [{referencing_file1}, {referencing_file2}] | {wildcard|tilde|relative|dw_api|explicit|superModule} |

**Ref Type 分類**:
- `wildcard`: `*/cartridge/...` 形式の require
- `tilde`: `~/cartridge/...` 形式の require
- `relative`: `./...` 形式の require
- `dw_api`: `dw/...` 形式の require
- `explicit`: 明示的カートリッジ名指定
- `superModule`: `module.superModule` 経由の参照

---

## Section 8: Unresolved / Dynamic Resolution

静的解析では解決できないパターンの一覧。手動レビューが必要。

| Pattern | File | Line | Reason | Note |
|---------|------|------|--------|------|
<!-- assembler: Insert unresolved pattern rows here -->
| `{code_pattern}` | {file_path} | {line_number} | {dynamic_require|conditional|computed_path|unknown} | {explanation} |

**Reason 分類**:
- `dynamic_require`: `require(variable)` のような動的 require
- `conditional`: 条件分岐内の require
- `computed_path`: 文字列結合でパスを組み立て
- `unknown`: その他の理由

<!-- assembler: If no unresolved patterns, display "該当なし" message -->

---

## Section 9: Dependency Graph Summary

### 9.1 Cartridge Dependency Graph

カートリッジ間の依存関係の可視化。実線は require 依存、破線は superModule 関係。

```mermaid
graph LR
    <!-- assembler: Generate mermaid graph from aggregated dependencies -->
    {cartridge1} -->|"{n} refs"| {cartridge2}
    {cartridge1} -->|"{n} refs"| {cartridge3}
    {cartridge2} -->|"{n} refs"| {cartridge3}
    {cartridge1} -.->|"{n} superModule"| {cartridge2}
    {cartridge2} -.->|"{n} superModule"| {cartridge3}
```

**グラフの読み方**:
- 実線 (-->): require による依存
- 破線 (-.->): module.superModule による継承関係
- エッジラベル: 参照数

### 9.2 Statistics

| Metric | Value |
|--------|-------|
<!-- assembler: Calculate and insert statistics from merged data -->
| Total require() calls | {total_require_count} |
| Wildcard requires (`*/`) | {wildcard_require_count} |
| Tilde requires (`~/`) | {tilde_require_count} |
| SuperModule chains | {supermodule_chain_count} |
| Max chain depth | {max_chain_depth} |
| Unresolved patterns | {unresolved_pattern_count} |
| Event listeners | {event_listener_count} |
| Hook definitions | {hook_definition_count} |
| Template overrides | {template_override_count} |

---

## Notes

このマップは SFRA Explorer スキルによって自動生成されました。

- **生成日時**: {generated_at}
- **Git コミット**: {git_commit}
- **カートリッジパス**: `{cartridge_path}`
- **信頼度**: {cartridge_path_confidence}

<!-- assembler: Add generation metadata and any warnings/notes at the end -->
