#!/bin/bash
# validate-map.sh
# Resolution Map の基本検証を実行する Stop hook
#
# 検証項目:
#   1. sfra-resolution-map.md が存在するか
#   2. YAML frontmatter が含まれているか
#   3. 9 セクションすべてが存在するか

MAP_FILE="docs/explore/sfra-resolution-map.md"

# 解決マップが存在しない場合はスキップ（Phase 2 のみの場合など）
if [ ! -f "$MAP_FILE" ]; then
  exit 0
fi

ERRORS=0

# YAML frontmatter チェック
if ! head -1 "$MAP_FILE" | grep -q "^---"; then
  echo "WARN: Resolution map missing YAML frontmatter"
  ERRORS=$((ERRORS + 1))
fi

# 9 セクションの存在チェック
SECTIONS=(
  "Section 1: Cartridge Stack"
  "Section 2: File Resolution Table"
  "Section 3: SuperModule Chains"
  "Section 4: Controller Route Map"
  "Section 5: Template Override Map"
  "Section 6: Hook Registration Map"
  "Section 7: Reverse Dependency Index"
  "Section 8: Unresolved"
  "Section 9: Dependency Graph Summary"
)

for section in "${SECTIONS[@]}"; do
  if ! grep -q "$section" "$MAP_FILE"; then
    echo "WARN: Missing section: $section"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo "Resolution map validation: $ERRORS warning(s)"
else
  echo "Resolution map validation: OK"
fi

# 警告のみ、失敗にはしない
exit 0
