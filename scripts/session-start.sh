#!/bin/bash
# Session Start Script - FlowGroove Project
# Usage: ./scripts/session-start.sh "Session goal"
#
# This script:
# 1. Reads NEXT_SESSION.md from previous session
# 2. Loads QWEN.md context
# 3. Initializes agent team if needed
# 4. Creates fresh todo list
# 5. Sets up session tracking

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QWEN_DIR="$PROJECT_ROOT/.qwen"
QWEN_MD="$PROJECT_ROOT/QWEN.md"
MEMORY_DIR="$PROJECT_ROOT/memory"

# Get session goal from argument
SESSION_GOAL="${1:-}"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Starting New Qwen Session                       ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📅 Date: $(date +%Y-%m-%d)"
echo "🕐 Time: $(date +%H:%M:%S)"
echo ""

# Step 1: Check for previous session context
echo "📋 Step 1: Checking previous session context..."
NEXT_SESSION_FILE="$QWEN_DIR/NEXT_SESSION.md"
SESSION_STATE_FILE="$QWEN_DIR/SESSION_STATE.md"

if [ -f "$NEXT_SESSION_FILE" ]; then
    echo "   ✅ Found NEXT_SESSION.md from previous session"
    echo ""
    echo "   ┌─────────────────────────────────────────────────────"
    echo "   │ Previous Session Context:"
    echo "   └─────────────────────────────────────────────────────"
    head -20 "$NEXT_SESSION_FILE" | grep -v "^---" | grep -v "^*Generated"
    echo "   ─────────────────────────────────────────────────────"
    echo ""
    
    # Ask if user wants to review full context
    read -p "📖 Review full NEXT_SESSION.md? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cat "$NEXT_SESSION_FILE"
        echo ""
    fi
else
    echo "   ℹ️  No previous session context found (first session?)"
fi
echo ""

# Step 2: Load QWEN.md context
echo "📚 Step 2: Loading QWEN.md context..."
if [ -f "$QWEN_MD" ]; then
    echo "   ✅ QWEN.md found"
    echo ""
    echo "   Recent patterns from QWEN.md:"
    echo "   ┌─────────────────────────────────────────────────────"
    grep -A 2 "### SESSION COMPLETE" "$QWEN_MD" | head -10
    echo "   ─────────────────────────────────────────────────────"
else
    echo "   ⚠️  QWEN.md not found - creating template..."
    cat > "$QWEN_MD" << 'EOF'
## Qwen Added Memories

### Active Session
**Started:** YYYY-MM-DD
**Goal:** 

**Key Decisions:**
- 

**Files Modified:**
- 

---

### Past Sessions
<!-- Completed sessions will be archived here -->

EOF
    echo "   ✅ Created QWEN.md template"
fi
echo ""

# Step 3: Check session state
echo "📊 Step 3: Checking session state..."
if [ -f "$SESSION_STATE_FILE" ]; then
    echo "   ✅ Found SESSION_STATE.md"
    LAST_SESSION=$(grep "**Session Ended:**" "$SESSION_STATE_FILE" 2>/dev/null | head -1 || echo "Unknown")
    echo "   Last session: $LAST_SESSION"
else
    echo "   ℹ️  No previous session state found"
fi
echo ""

# Step 4: Git status check
echo "🔀 Step 4: Checking git status..."
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "Unknown")
echo "   Current branch: $CURRENT_BRANCH"

UNCOMMITTED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNCOMMITTED" -gt 0 ]; then
    echo "   ⚠️  You have $UNCOMMITTED uncommitted changes"
    echo ""
    echo "   Uncommitted files:"
    git status --short 2>/dev/null | head -10
    echo ""
    read -p "🔧 Commit these before starting new session? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add -A
        git commit -m "chore: Pre-session cleanup $(date +%Y-%m-%d)"
        echo "   ✅ Changes committed"
    fi
else
    echo "   ✅ Working tree clean"
fi
echo ""

# Step 5: Set session goal
echo "🎯 Step 5: Session goal..."
if [ -z "$SESSION_GOAL" ]; then
    echo "   Enter the main goal for this session:"
    echo "   (e.g., 'Fix theme compliance', 'Add new feature', 'Refactor auth')"
    read -p "   Goal: " SESSION_GOAL
fi

if [ -n "$SESSION_GOAL" ]; then
    echo "   ✅ Session goal: $SESSION_GOAL"
else
    SESSION_GOAL="General development"
    echo "   ℹ️  Using default goal: $SESSION_GOAL"
fi
echo ""

# Step 6: Initialize agent team (if needed)
echo "🤖 Step 6: Agent team status..."
if [ -d "$QWEN_DIR/agents" ]; then
    AGENT_COUNT=$(ls -1 "$QWEN_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "   ✅ $AGENT_COUNT specialist agents available"
    echo ""
    echo "   Available agents:"
    ls -1 "$QWEN_DIR/agents"/*.md 2>/dev/null | xargs -I {} basename {} .md | sed 's/^/   - /'
else
    echo "   ℹ️  No specialist agents configured"
    echo "   Agents will be activated on-demand"
fi
echo ""

# Step 7: Create session tracking file
echo "📝 Step 7: Creating session tracking..."
SESSION_TRACKING="$QWEN_DIR/ACTIVE_SESSION.md"

cat > "$SESSION_TRACKING" << EOF
# Active Session - $(date +%Y-%m-%d)

**Started:** $(date +"%Y-%m-%d %H:%M:%S")
**Goal:** $SESSION_GOAL

## Current Focus
- $SESSION_GOAL

## Tasks
<!-- Add tasks as they come up -->
- [ ] 

## Files Modified
<!-- Track files changed this session -->
- 

## Agents Used
<!-- Track which agents were activated -->
- 

## Decisions Made
<!-- Record important decisions -->
- 

## Notes
<!-- Session notes and observations -->

---
*Created by session-start.sh*
EOF

echo "   ✅ Session tracking created: $SESSION_TRACKING"
echo ""

# Step 8: Show summary
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           ✅ Session Started Successfully                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Session Info:"
echo "   Goal: $SESSION_GOAL"
echo "   Branch: $CURRENT_BRANCH"
echo "   Time: $(date +"%H:%M:%S")"
echo ""
echo "📁 Session Files:"
echo "   - $SESSION_TRACKING (active tracking)"
echo "   - $QWEN_MD (project memory)"
if [ -f "$NEXT_SESSION_FILE" ]; then
    echo "   - $NEXT_SESSION_FILE (previous context)"
fi
echo ""
echo "🎯 Quick Start:"
echo "   1. Review your goal: $SESSION_GOAL"
echo "   2. Check ACTIVE_SESSION.md for task tracking"
echo "   3. Start working! Agents will activate on-demand"
echo ""
echo "💡 Tips:"
echo "   - Use 'todo_write' tool to track tasks"
echo "   - Delegate to specialist agents when needed"
echo "   - Run ./scripts/session-end.sh when done"
echo ""
echo "🚀 Ready to start!"
echo ""
