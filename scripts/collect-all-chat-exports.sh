#!/bin/bash
# Collect All Chat Exports from All Branches
# This script gathers all Qwen chat exports and conversation logs

set -e

OUTPUT_DIR="chat-exports-collection"
mkdir -p "$OUTPUT_DIR"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║      Collecting All Chat Exports from All Branches        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get all branches
echo -e "${BLUE}📋 Getting all branches...${NC}"
branches=$(git branch -a --format='%(refname:short)' | grep -v "HEAD" | sort -u)
echo "Found branches:"
echo "$branches"
echo ""

# Collect exports from each branch
echo -e "${YELLOW}🔍 Searching for export files in all branches...${NC}"
echo ""

# Create index file
cat > "$OUTPUT_DIR/README.md" << 'EOF'
# Chat Exports Collection

**Collected:** March 14, 2026  
**Purpose:** Preserve all Qwen chat conversations for analysis

## Structure

```
chat-exports-collection/
├── README.md              # This file
├── INDEX.md               # Complete index of all exports
├── by-branch/             # Exports organized by branch
│   └── <branch-name>/
│       └── <export-file>.md
├── by-date/               # Exports organized by date
│   └── 2026-03-XX/
│       └── <export-file>.md
└── combined/              # Combined conversations
    └── all-conversations.md
```

## How to Use

1. **Browse by branch:** Check `by-branch/` folder
2. **Browse by date:** Check `by-date/` folder
3. **Search all:** Use `INDEX.md`
4. **Read combined:** Check `combined/all-conversations.md`

## Analysis Tips

- Look for solutions to recurring problems
- Find when specific features were implemented
- Track decision-making process
- Identify what was tried and failed

EOF

# Counter
total_files=0

# Process each branch
for branch in $branches; do
    echo -e "${BLUE}Processing branch: $branch${NC}"
    
    # Create branch directory
    branch_dir="$OUTPUT_DIR/by-branch/$(echo $branch | tr '/' '_')"
    mkdir -p "$branch_dir"
    
    # Find all qwen export files in this branch
    export_files=$(git ls-tree -r --name-only "$branch" 2>/dev/null | grep -E "qwen-code-export|chat-export" | grep "\.md$" || true)
    
    if [ -n "$export_files" ]; then
        echo "  Found export files:"
        
        for file in $export_files; do
            # Extract file from branch
            filename=$(basename "$file")
            echo "    - $filename"
            
            # Save to by-branch
            git show "$branch:$file" > "$branch_dir/$filename" 2>/dev/null || true
            
            # Extract date for by-date organization
            date_part=$(echo "$filename" | grep -oE "20[0-9]{2}-[0-9]{2}-[0-9]{2}" || echo "unknown")
            date_dir="$OUTPUT_DIR/by-date/$date_part"
            mkdir -p "$date_dir"
            
            # Save to by-date
            cp "$branch_dir/$filename" "$date_dir/$filename" 2>/dev/null || true
            
            # Add to index
            echo "- **$branch**: \`$file\`" >> "$OUTPUT_DIR/INDEX.md"
            
            total_files=$((total_files + 1))
        done
        
        echo ""
    else
        echo "  No export files found"
        echo ""
    fi
done

# Also collect current directory exports
echo -e "${YELLOW}📁 Collecting current directory exports...${NC}"
current_exports=$(find . -maxdepth 1 -name "qwen-code-export*.md" -o -name "chat-export*.md" -o -name "chat-export*.json" 2>/dev/null)

if [ -n "$current_exports" ]; then
    for file in $current_exports; do
        if [ -f "$file" ]; then
            echo "  - $(basename $file)"
            cp "$file" "$OUTPUT_DIR/by-branch/CURRENT/" 2>/dev/null || mkdir -p "$OUTPUT_DIR/by-branch/CURRENT" && cp "$file" "$OUTPUT_DIR/by-branch/CURRENT/"
            total_files=$((total_files + 1))
        fi
    done
    echo ""
fi

# Create combined file
echo -e "${BLUE}📝 Creating combined conversations file...${NC}"
cat > "$OUTPUT_DIR/combined/all-conversations.md" << 'EOF'
# All Chat Conversations (Combined)

**Note:** This is a combined file of all chat exports.
Use search (Ctrl+F) to find specific topics.

---

EOF

# Combine all markdown files
for branch_dir in "$OUTPUT_DIR/by-branch"/*/; do
    if [ -d "$branch_dir" ]; then
        branch_name=$(basename "$branch_dir")
        echo "## Branch: $branch_name" >> "$OUTPUT_DIR/combined/all-conversations.md"
        echo "" >> "$OUTPUT_DIR/combined/all-conversations.md"
        
        for md_file in "$branch_dir"/*.md; do
            if [ -f "$md_file" ]; then
                filename=$(basename "$md_file")
                echo "### File: $filename" >> "$OUTPUT_DIR/combined/all-conversations.md"
                echo "" >> "$OUTPUT_DIR/combined/all-conversations.md"
                echo '```markdown' >> "$OUTPUT_DIR/combined/all-conversations.md"
                cat "$md_file" >> "$OUTPUT_DIR/combined/all-conversations.md"
                echo '```' >> "$OUTPUT_DIR/combined/all-conversations.md"
                echo "" >> "$OUTPUT_DIR/combined/all-conversations.md"
            fi
        done
    fi
done

# Update README
cat >> "$OUTPUT_DIR/README.md" << EOF

## Statistics

- **Total Export Files:** $total_files
- **Branches Processed:** $(echo "$branches" | wc -l | tr -d ' ')
- **Collection Date:** $(date)

## Quick Links

- [Browse by Branch](by-branch/)
- [Browse by Date](by-date/)
- [Combined File](combined/all-conversations.md)
- [Index](INDEX.md)

EOF

# Create summary
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ Collection Complete!                                ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📁 Output directory:${NC} $OUTPUT_DIR/"
echo -e "${BLUE}📊 Total files collected:${NC} $total_files"
echo ""
echo -e "${YELLOW}📄 Directory structure:${NC}"
find "$OUTPUT_DIR" -type f -name "*.md" | head -20
echo ""
echo -e "${YELLOW}💡 To search all exports:${NC}"
echo "   grep -r \"search_term\" $OUTPUT_DIR/"
echo ""
echo -e "${YELLOW}💡 To view combined file:${NC}"
echo "   cat $OUTPUT_DIR/combined/all-conversations.md | less"
echo ""
