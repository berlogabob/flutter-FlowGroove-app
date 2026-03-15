#!/bin/bash
# Move chat exports to archive folder
# Usage: ./scripts/move-chat-exports.sh

set -e

echo "📦 Moving chat exports to docs/archive/..."

# Move chat export JSON files
if ls *.json 1>/dev/null 2>&1; then
  for file in chat-export-*.json *-export-*.json; do
    if [ -f "$file" ]; then
      mv "$file" docs/archive/
      echo "  ✅ Moved: $file"
    fi
  done
fi

# Move qwen code export MD files
if ls qwen-code-export-*.md 1>/dev/null 2>&1; then
  for file in qwen-code-export-*.md; do
    if [ -f "$file" ]; then
      mv "$file" docs/archive/
      echo "  ✅ Moved: $file"
    fi
  done
fi

echo "✅ Chat exports moved to docs/archive/"
echo ""
echo "📁 Archive contents:"
ls -1 docs/archive/ | grep -E "(export|qwen)" || echo "  (no exports yet)"
