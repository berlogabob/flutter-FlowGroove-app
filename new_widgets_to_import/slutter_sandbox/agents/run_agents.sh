#!/bin/bash

# Multi-Agent Development Script for Song Structure Constructor
# This script orchestrates the 5 agents to develop the Flutter widget

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
OUTPUT_DIR="$SCRIPT_DIR/../agent_output"

mkdir -p "$OUTPUT_DIR"

echo "🚀 Starting Multi-Agent Development Pipeline"
echo "============================================"

# Check if qwen command is available
if ! command -v qwen &> /dev/null; then
    echo "❌ Error: qwen CLI not found. Please install it first."
    exit 1
fi

echo ""
echo "📋 Step 1/5: Running Planner Agent..."
echo "-------------------------------------"
planner_prompt=$(cat "$AGENTS_DIR/planner_agent.md")
planner_output="$OUTPUT_DIR/plan.json"

qwen --prompt "$planner_prompt

## Input Data
Project Description:
- Widget for constructing song structure like a puzzle
- Sections: Intro, Verse, Chorus, Bridge, Pre-Chorus, Outro, Instrumental
- Drag-and-drop reordering with ReorderableListView (horizontal)
- Tap to edit, button to delete
- Template library + custom input
- Optional text notes per section (e.g., guitar chords)
- Minimal design, touch-friendly interface
" > "$planner_output" 2>&1

echo "✅ Plan saved to: $planner_output"

echo ""
echo "🎨 Step 2/5: Running UI Designer Agent..."
echo "-----------------------------------------"
designer_prompt=$(cat "$AGENTS_DIR/ui_designer_agent.md")
designer_output="$OUTPUT_DIR/design.md"

# Note: In a real scenario, you would pass the plan from step 1
qwen --prompt "$designer_prompt

## Input
Plan from Planner Agent: See $planner_output
" > "$designer_output" 2>&1

echo "✅ Design saved to: $designer_output"

echo ""
echo "💻 Step 3/5: Running Coder Agent..."
echo "-----------------------------------"
coder_prompt=$(cat "$AGENTS_DIR/coder_agent.md")
coder_output="$OUTPUT_DIR/code.md"

qwen --prompt "$coder_prompt

## Input Data
- Plan from Planner: See $planner_output
- Design from UI Designer: See $designer_output
" > "$coder_output" 2>&1

echo "✅ Code saved to: $coder_output"

echo ""
echo "🧪 Step 4/5: Running Tester Agent..."
echo "------------------------------------"
tester_prompt=$(cat "$AGENTS_DIR/tester_agent.md")
tester_output="$OUTPUT_DIR/tests.json"

qwen --prompt "$tester_prompt

## Input Data
Code from Coder Agent: See $coder_output
" > "$tester_output" 2>&1

echo "✅ Tests saved to: $tester_output"

echo ""
echo "📦 Step 5/5: Running Integrator Agent..."
echo "----------------------------------------"
integrator_prompt=$(cat "$AGENTS_DIR/integrator_agent.md")
integrator_output="$OUTPUT_DIR/integration.md"

qwen --prompt "$integrator_prompt

## Input Data
- Plan: See $planner_output
- Design: See $designer_output
- Code: See $coder_output
- Tests: See $tester_output
" > "$integrator_output" 2>&1

echo "✅ Integration report saved to: $integrator_output"

echo ""
echo "============================================"
echo "🎉 Multi-Agent Pipeline Complete!"
echo ""
echo "Output files:"
echo "  - Plan:     $planner_output"
echo "  - Design:   $designer_output"
echo "  - Code:     $coder_output"
echo "  - Tests:    $tester_output"
echo "  - Final:    $integrator_output"
echo ""
