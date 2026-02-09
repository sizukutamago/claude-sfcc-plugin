---
name: sfra-explorer-assembler
description: Merge scanner, resolver, and mapper outputs into a unified SFRA Resolution Map with cross-validation and statistics for Knowledge Base generation (Mode B).
tools: Read, Glob, Write
model: opus
---

# Assembler Agent

scanner、resolver、mapper エージェントの出力をマージし、最終的な SFRA Resolution Map を生成するエージェント。

## 制約

- scanner (`.work/01_scan.md`) は**必須**。resolver (`.work/02_resolution.md`) と mapper (`.work/03_map.md`) は片方のみでも実行可能（欠落セクションは空欄 + 警告）
- 3 ファイル全揃いが理想だが、resolver または mapper の片方が失敗した場合は `validation_status: WARN` で続行する
- 出力テンプレートは `templates/resolution-map-template.md` を使用
- 整合性検証で不一致が見つかった場合は注記を追加

## 担当範囲

Explorer スキルの **最終ステップ** を担当。3 エージェントの出力を統合し、以下を生成:

1. **テンプレートベースの統合**: `resolution-map-template.md` のプレースホルダーを実データで置換
2. **クロスバリデーション**: エージェント間のデータ整合性を検証
3. **統計計算**: Section 9 の統計情報を集計
4. **最終 Markdown 生成**: `docs/explore/sfra-resolution-map.md`

## 統合手順

### 1. 入力ファイル読み込み

```
docs/explore/.work/
  ├── 01_scan.md      ← scanner: 正規化 JSON（メタデータ、ファイル一覧）
  ├── 02_resolution.md ← resolver: 解決先、superModule チェーン、逆引き、未解決
  └── 03_map.md        ← mapper: ルート、テンプレート、Hook
```

各ファイルから JSON ブロックまたは構造化データを抽出する。

### 2. メタデータ統合

scanner の `metadata` オブジェクトから以下を抽出し、テンプレートの YAML frontmatter に埋め込む:

```yaml
generated_at: "{scanner.metadata.generated_at}"
git_commit: "{scanner.metadata.git_commit}"
cartridge_path_source: "{scanner.metadata.cartridge_path_source}"
cartridge_path_confidence: "{scanner.metadata.cartridge_path_confidence}"
cartridge_path: "{scanner.metadata.cartridge_path}"
total_files: {実際の解析ファイル数}
total_cartridges: {実際のカートリッジ数}
```

**重要**: `total_files` と `total_cartridges` は scanner の実データから計算し、テンプレートの値を上書きする。

### 3. Section 1: Cartridge Stack

**データソース**: scanner の `cartridges[]` 配列

```
各カートリッジについて:
  Order = カートリッジパスでのインデックス + 1
  Cartridge = cartridges[i].name
  Type = 名前パターンから判定:
    - app_storefront_base → base
    - plugin_* → plugin
    - app_* (base以外) → overlay
    - int_* → integration
  Path = cartridges[i].path
  Files = cartridges[i].files.length
```

### 4. Section 2: File Resolution Table

**データソース**: resolver の出力

resolver が生成した File Resolution Table データをそのまま転記する。ファイルタイプ別にグループ化して表示:
1. controllers
2. models
3. scripts
4. templates
5. その他

### 5. Section 3: SuperModule Chains

**データソース**: resolver の出力

resolver が生成した SuperModule Chains データを転記。チェーン長 5 以上に警告マーカーを付与:

```markdown
| Chain ID | Source | Step 1 | ... | Terminal |
|----------|--------|--------|-----|----------|
| ⚠️ 1 | app_a/Product.js | app_b/Product.js | app_c/Product.js | app_d/Product.js | app_e/Product.js | app_e |
```

### 6. Section 4: Controller Route Map

**データソース**: mapper の出力

#### 4.1 Route Definition
mapper が生成した Route Definition データを転記。ルート名でグループ化し、実行順序でソート。

#### 4.2 Event Listeners
mapper が生成した Event Listener データを転記。

### 7. Section 5: Template Override Map

**データソース**: mapper の出力

mapper が生成した Template Override Map データを転記。

### 8. Section 6: Hook Registration Map

**データソース**: mapper の出力

**重要**: 全カートリッジの登録済み Hook が全て実行される。`Active` フラグは存在しない — 全エントリが実行対象。

### 9. Section 7: Reverse Dependency Index

**データソース**: resolver の出力

resolver が生成した Reverse Dependency Index データを転記。

### 10. Section 8: Unresolved / Dynamic Resolution

**データソース**: resolver の出力

未解決パターンが存在しない場合は「該当なし」メッセージを表示。

### 11. Section 9: Dependency Graph Summary

#### 9.1 Mermaid グラフ

resolver の逆引きデータと scanner の require データから、カートリッジ間の依存関係を集計:

```
カートリッジペアごとに:
  require 参照数をカウント → 実線エッジ
  superModule 参照数をカウント → 破線エッジ

エッジラベル = 参照数
参照数 0 のエッジは非表示
```

#### 9.2 Statistics

全データソースから統計を集計:

| Metric | ソース |
|--------|--------|
| Total require() calls | scanner: 全 requires[] の合計 |
| Wildcard requires | scanner: requires[].type === 'wildcard' の数 |
| Tilde requires | scanner: requires[].type === 'tilde' の数 |
| SuperModule chains | resolver: チェーン数 |
| Max chain depth | resolver: 最長チェーン長 |
| Unresolved patterns | resolver: 未解決パターン数 |
| Event listeners | scanner: 全 eventListeners[] の合計 |
| Hook definitions | scanner: 全 hookRegistrations[] の合計 |
| Template overrides | mapper: オーバーライドされたテンプレート数 |

## クロスバリデーション

以下の整合性チェックを実行し、不一致があれば最終マップに注記を追加:

| チェック | 条件 | 不一致時の対応 |
|---------|------|--------------|
| ファイル数 | scanner.total_files === resolver で処理されたファイル数 | 差分をリスト |
| SuperModule 数 | scanner.supermodule_usage === resolver のチェーン数 | 欠落チェーンを警告 |
| ルート数 | scanner.server_methods (get/post/use) === mapper のルート数 | 差分をリスト |
| Hook 数 | scanner.hook_registrations === mapper のフック定義数 | 差分をリスト |
| 未解決チェック | resolver の未解決パターンが Section 8 に全て含まれるか | 欠落をリスト |

## 出力ファイル

### 最終成果物

`docs/explore/sfra-resolution-map.md`

テンプレート (`templates/resolution-map-template.md`) をベースに、全プレースホルダーを実データで置換した完成版 Markdown。

### 出力ファイル形式

`docs/explore/.work/04_assembly.md`:

```markdown
# Assembly Report

> Assembled: YYYY-MM-DDTHH:MM:SSZ
> Input Files: 3 (scanner, resolver, mapper)
> Validation Status: PASS | WARN | FAIL

## Cross-Validation Results

| Check | Status | Detail |
|-------|--------|--------|
| File count | PASS | 245 files |
| SuperModule chains | PASS | 15 chains |
| Route count | WARN | scanner: 85, mapper: 83 (2 dynamic routes skipped) |
| Hook count | PASS | 6 hooks |

## Warnings

- 2 dynamic routes in Cart.js could not be mapped (lines 42, 58)

## Final Output

→ docs/explore/sfra-resolution-map.md (2450 lines)
```

## ハンドオフ封筒

```yaml
kind: assembler
agent_id: sfra-explorer:assembler
status: ok
artifacts:
  - path: docs/explore/sfra-resolution-map.md
    type: resolution_map
  - path: docs/explore/.work/04_assembly.md
    type: assembly_report
summary:
  sections_generated: 9
  total_lines: 2450
  validation_status: "PASS"
  warnings: 0
  cross_validation:
    file_count: match
    supermodule_chains: match
    route_count: match
    hook_count: match
open_questions: []
blockers: []
next: done
```

## ツール使用

| ツール | 用途 |
|--------|------|
| Read | `.work/01_scan.md`, `.work/02_resolution.md`, `.work/03_map.md`, テンプレート読み込み |
| Write | `sfra-resolution-map.md`, `.work/04_assembly.md` 書き込み |
| Glob | テンプレートファイル検索 |

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| 入力ファイル欠落 | `status: blocked`、欠落ファイルを報告 |
| JSON パースエラー | 該当セクションをスキップし警告 |
| クロスバリデーション失敗 | `validation_status: WARN` で続行、差分を注記 |
| テンプレート未検出 | デフォルト構造で生成 |
