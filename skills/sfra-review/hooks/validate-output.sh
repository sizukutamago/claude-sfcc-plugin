#!/bin/bash
# validate-output.sh
# Validates that handoff envelope files contain required YAML fields.
# Used as a PostToolUse:Write hook to catch malformed agent output.

FILE_PATH="${TOOL_INPUT_FILE_PATH:-}"

# Only validate files in the .work directory
if [[ "$FILE_PATH" != *".work/"* ]]; then
  exit 0
fi

# Only validate markdown files
if [[ "$FILE_PATH" != *.md ]]; then
  exit 0
fi

# Check for required handoff envelope fields
if grep -q "^kind:" "$FILE_PATH" 2>/dev/null; then
  # This looks like a handoff envelope — validate required fields
  MISSING=""
  for field in "kind:" "agent_id:" "status:" "findings:" "summary:" "next:"; do
    if ! grep -q "$field" "$FILE_PATH" 2>/dev/null; then
      MISSING="$MISSING $field"
    fi
  done

  if [ -n "$MISSING" ]; then
    echo "WARNING: Handoff envelope missing fields:$MISSING in $FILE_PATH"
    # Don't fail — just warn
    exit 0
  fi
fi

exit 0
