#!/bin/bash
# Session Start Script - FlowGroove Project
# Usage: ./scripts/session-start.sh "Session goal"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CODEX_DIR="$PROJECT_ROOT/.codex"
SESSION_DIR="$CODEX_DIR/sessions"
HANDOFF_FILE="$CODEX_DIR/HANDOFF.md"
STATUS_FILE="$CODEX_DIR/STATUS.md"
MEMORY_FILE="$CODEX_DIR/MEMORY.md"
AGENTS_DIR="$CODEX_DIR/agents"

mkdir -p "$SESSION_DIR"

SESSION_GOAL="${1:-}"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Starting New Codex Session                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📅 Date: $(date +%Y-%m-%d)"
echo "🕐 Time: $(date +%H:%M:%S)"
echo ""

echo "📋 Step 1: Checking handoff and status..."
if [ -f "$HANDOFF_FILE" ]; then
    echo "   ✅ Found HANDOFF.md"
    echo "   Preview:"
    head -20 "$HANDOFF_FILE" | grep -v "^$" | sed 's/^/   /'
else
    echo "   ℹ️  No HANDOFF.md found"
fi

if [ -f "$STATUS_FILE" ]; then
    echo "   ✅ Found STATUS.md"
else
    echo "   ℹ️  No STATUS.md found"
fi
echo ""

echo "📚 Step 2: Reviewing durable memory..."
if [ -f "$MEMORY_FILE" ]; then
    echo "   ✅ Found MEMORY.md"
    echo "   Key sections:"
    grep '^## ' "$MEMORY_FILE" | sed 's/^/   /'
else
    echo "   ⚠️  MEMORY.md not found"
fi
echo ""

echo "🔀 Step 3: Checking git status..."
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "Unknown")
echo "   Current branch: $CURRENT_BRANCH"

UNCOMMITTED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNCOMMITTED" -gt 0 ]; then
    echo "   ⚠️  You have $UNCOMMITTED uncommitted changes"
    git status --short 2>/dev/null | head -10 | sed 's/^/   /'
else
    echo "   ✅ Working tree clean"
fi
echo ""

echo "🎯 Step 4: Session goal..."
if [ -z "$SESSION_GOAL" ]; then
    read -r -p "   Goal: " SESSION_GOAL
fi

if [ -z "$SESSION_GOAL" ]; then
    SESSION_GOAL="General development"
fi
echo "   ✅ Session goal: $SESSION_GOAL"
echo ""

echo "🤖 Step 5: Agent inventory..."
if [ -d "$AGENTS_DIR" ]; then
    AGENT_COUNT=$(find "$AGENTS_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
    echo "   ✅ $AGENT_COUNT specialist agents available"
    find "$AGENTS_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort | xargs -I {} basename {} .md | sed 's/^/   - /'
else
    echo "   ℹ️  No agent directory found"
fi
echo ""

echo "📝 Step 6: Creating session tracking snapshot..."
SESSION_TRACKING="$SESSION_DIR/ACTIVE_SESSION.md"

cat > "$SESSION_TRACKING" << EOF
# Active Session - $(date +%Y-%m-%d)

**Started:** $(date +"%Y-%m-%d %H:%M:%S")
**Goal:** $SESSION_GOAL
**Branch:** $CURRENT_BRANCH

## Control Plane
- Read first: .codex/AGENTS.md
- Durable memory: .codex/MEMORY.md
- Current state: .codex/STATUS.md
- Baton pass: .codex/HANDOFF.md

## Current Focus
- $SESSION_GOAL

## Tasks
- [ ] 

## Files Modified
- 

## Decisions Made
- 

## Notes

---
*Created by session-start.sh*
EOF

echo "   ✅ Session tracking created: $SESSION_TRACKING"
echo ""

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
echo "   - $SESSION_TRACKING"
echo "   - $MEMORY_FILE"
echo "   - $STATUS_FILE"
echo "   - $HANDOFF_FILE"
echo ""
echo "🎯 Quick Start:"
echo "   1. Review .codex/AGENTS.md"
echo "   2. Execute one bounded milestone"
echo "   3. Update STATUS.md and HANDOFF.md before stopping"
echo ""
