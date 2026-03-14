#!/bin/bash
# Git History Analysis Script for FlowGroove
# This script helps analyze code changes across all branches

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         FlowGroove Git History Analysis                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output directory
OUTPUT_DIR="git-history-analysis"
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}📊 Generating Git History Report...${NC}"
echo ""

# 1. List all branches
echo -e "${YELLOW}1. All Branches:${NC}"
git branch -a --format='%(refname:short) %(committerdate:short)' | sort -k2 -r > "$OUTPUT_DIR/branches.txt"
cat "$OUTPUT_DIR/branches.txt"
echo ""

# 2. List all tags
echo -e "${YELLOW}2. All Tags:${NC}"
git tag -l --format='%(refname:short) %(creatordate:short)' | sort -k2 -r > "$OUTPUT_DIR/tags.txt"
cat "$OUTPUT_DIR/tags.txt"
echo ""

# 3. Recent commits across all branches
echo -e "${YELLOW}3. Recent Commits (Last 50):${NC}"
git log --all --oneline --graph --decorate -50 > "$OUTPUT_DIR/recent-commits.txt"
cat "$OUTPUT_DIR/recent-commits.txt"
echo ""

# 4. Find commits by date range
echo -e "${YELLOW}4. Commits from March 13-14, 2026:${NC}"
git log --all --oneline --since="2026-03-13" --until="2026-03-15" --date=short --format='%h %ad %s' > "$OUTPUT_DIR/march-13-14-commits.txt"
cat "$OUTPUT_DIR/march-13-14-commits.txt"
echo ""

# 5. Find commits that touch specific files
echo -e "${YELLOW}5. Commits touching key files:${NC}"
echo "" > "$OUTPUT_DIR/file-commits.txt"

for file in "lib/main.dart" "lib/screens/profile_screen.dart" "pubspec.yaml" "lib/services/analytics_service.dart"; do
    echo "=== $file ===" >> "$OUTPUT_DIR/file-commits.txt"
    git log --all --oneline -- "$file" | head -10 >> "$OUTPUT_DIR/file-commits.txt"
    echo "" >> "$OUTPUT_DIR/file-commits.txt"
done

cat "$OUTPUT_DIR/file-commits.txt"
echo ""

# 6. Compare specific branches
echo -e "${YELLOW}6. Branch Comparison:${NC}"
echo "" > "$OUTPUT_DIR/branch-diffs.txt"

branches=("second01" "feature/march-14-complete" "backup/march-14-analytics-fix" "feature/tools-migration-backup")

for i in "${!branches[@]}"; do
    for j in "${!branches[@]}"; do
        if [ $i -lt $j ]; then
            branch1="${branches[$i]}"
            branch2="${branches[$j]}"
            echo "=== $branch1 vs $branch2 ===" >> "$OUTPUT_DIR/branch-diffs.txt"
            git diff --stat "$branch1" "$branch2" >> "$OUTPUT_DIR/branch-diffs.txt" 2>/dev/null || echo "Cannot compare" >> "$OUTPUT_DIR/branch-diffs.txt"
            echo "" >> "$OUTPUT_DIR/branch-diffs.txt"
        fi
    done
done

cat "$OUTPUT_DIR/branch-diffs.txt"
echo ""

# 7. Find commits with specific keywords
echo -e "${YELLOW}7. Commits with Keywords:${NC}"
echo "" > "$OUTPUT_DIR/keyword-commits.txt"

keywords=("analytics" "firebase" "web" "profile" "ko-fi" "memory" "fix" "deploy")

for keyword in "${keywords[@]}"; do
    echo "=== Keyword: $keyword ===" >> "$OUTPUT_DIR/keyword-commits.txt"
    git log --all --oneline --grep="$keyword" -i | head -5 >> "$OUTPUT_DIR/keyword-commits.txt"
    echo "" >> "$OUTPUT_DIR/keyword-commits.txt"
done

cat "$OUTPUT_DIR/keyword-commits.txt"
echo ""

# 8. Show working tree changes
echo -e "${YELLOW}8. Current Working Tree:${NC}"
git status --short > "$OUTPUT_DIR/working-tree.txt"
cat "$OUTPUT_DIR/working-tree.txt"
echo ""

# 9. Create patch files for important branches
echo -e "${YELLOW}9. Creating Patch Files:${NC}"

# Patch from working version to current
git diff backup/march-14-analytics-fix second01 > "$OUTPUT_DIR/working-to-current.patch" 2>/dev/null || echo "Cannot create patch"
echo "✅ Created: working-to-current.patch"

# Patch from broken to fixed
git diff feature/tools-migration-backup feature/march-14-complete > "$OUTPUT_DIR/broken-to-fixed.patch" 2>/dev/null || echo "Cannot create patch"
echo "✅ Created: broken-to-fixed.patch"

echo ""

# 10. Generate summary
echo -e "${YELLOW}10. Summary:${NC}"
cat > "$OUTPUT_DIR/SUMMARY.md" << EOF
# Git History Analysis Summary

**Generated:** $(date)
**Repository:** FlowGroove (flutter_repsync_app)

## Key Branches

| Branch | Purpose | Status |
|--------|---------|--------|
| second01 | Current development | ✅ Active |
| feature/march-14-complete | Working version with Memory System | ✅ Working |
| backup/march-14-analytics-fix | Analytics fix backup | ✅ Working |
| feature/tools-migration-backup | Development (broken web) | ⚠️ Broken |
| main | Production | 🚀 Production |

## Key Commits

$(git log --all --oneline --since="2026-03-13" --until="2026-03-15" | head -20)

## Files Changed

$(git diff --stat backup/march-14-analytics-fix second01 2>/dev/null || echo "N/A")

## Recommendations

1. Use \`second01\` for current development
2. Reference \`feature/march-14-complete\` for working code
3. Avoid \`feature/tools-migration-backup\` (broken web)
4. Always test web build after Firebase changes

## Analysis Files Generated

- branches.txt - All branches
- tags.txt - All tags
- recent-commits.txt - Recent commits
- march-13-14-commits.txt - Commits from critical dates
- file-commits.txt - Commits touching key files
- branch-diffs.txt - Branch comparisons
- keyword-commits.txt - Commits by keyword
- working-tree.txt - Current changes
- working-to-current.patch - Patch file
- broken-to-fixed.patch - Fix patch
EOF

echo "✅ Created: SUMMARY.md"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ Analysis Complete!                                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📁 Output directory:${NC} $OUTPUT_DIR/"
echo -e "${BLUE}📄 Files generated:${NC}"
ls -la "$OUTPUT_DIR/"
echo ""
echo -e "${YELLOW}💡 To view detailed diff between branches:${NC}"
echo "   git diff <branch1> <branch2>"
echo ""
echo -e "${YELLOW}💡 To search for specific changes:${NC}"
echo "   git log --all -S\"search_term\" --oneline"
echo ""
echo -e "${YELLOW}💡 To restore file from old commit:${NC}"
echo "   git checkout <commit-hash> -- <file>"
echo ""
