# Qwen Agents for Song Structure Constructor

This folder contains agent prompts for developing the "Song Structure Constructor" Flutter widget using Qwen CLI or similar multi-agent systems.

## Agents Overview

| Agent | Role | Input | Output |
|-------|------|-------|--------|
| `planner_agent.md` | Project planning and task breakdown | Project description | JSON plan with requirements, files, dependencies, milestones |
| `ui_designer_agent.md` | UI/UX design and user flow | Plan from Planner | Markdown with layouts, user flow, components |
| `coder_agent.md` | Code implementation | Plan + Design | Dart code files |
| `tester_agent.md` | Testing and quality assurance | Code from Coder | JSON with tests, issues, report |
| `integrator_agent.md` | Final integration and documentation | All artifacts | Complete project with README |
| `code_quality_agent.md` | Code quality and refactoring | Code files | Markdown report with issues and recommendations |

## Workflow

```
┌─────────────────┐
│  User Request   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Planner Agent   │───► Plan (JSON)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ UI Designer     │───► Design (Markdown)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Coder Agent    │───► Code (Dart files)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Tester Agent   │───► Tests + Report (JSON)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Code Quality Agent│───► Quality Report (Markdown)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Integrator Agent│───► Final Project + README
└─────────────────┘
```

## Usage with Qwen CLI

### Example: Running the Planner Agent

```bash
qwen --prompt "
$(cat agents/planner_agent.md)

## Input Data
Project Description:
- Widget for constructing song structure like a puzzle
- Sections: Intro, Verse, Chorus, Bridge, Pre-Chorus, Outro, Instrumental
- Drag-and-drop reordering with ReorderableListView (horizontal)
- Tap to edit, button to delete
- Template library + custom input
- Optional text notes per section (e.g., guitar chords)
- Minimal design, touch-friendly interface
"
```

### Example: Running the Coder Agent

```bash
qwen --prompt "
$(cat agents/coder_agent.md)

## Input Data
- Plan from Planner: {PLAN_JSON_HERE}
- Design from UI Designer: {DESIGN_MARKDOWN_HERE}
"
```

## Shared State

Agents share state through artifacts:
- **Plan**: JSON with requirements, files, dependencies, milestones
- **Design**: Markdown with layouts, user flow, components
- **Code**: Dart files organized by lib/ structure
- **Tests**: JSON with test files, issues, report
- **Final**: Complete project structure with README

## Agent Communication Protocol

Each agent should:
1. Read its input from previous agents
2. Process according to its role
3. Output in the specified format
4. Pass output to the next agent

## Customization

Modify agent prompts to:
- Add project-specific constraints
- Change output formats
- Include additional quality checks
- Integrate with CI/CD pipelines

## Best Practices

1. **Sequential Execution**: Run agents in order (Planner → Designer → Coder → Tester → Integrator)
2. **Validation**: Validate each agent's output before passing to the next
3. **Iteration**: Allow agents to revise based on feedback
4. **Documentation**: Keep all artifacts for reference

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Agent output not in expected format | Add stricter format constraints to prompt |
| Code doesn't compile | Run Tester Agent to identify issues |
| Missing features | Review Planner Agent requirements |
| UI doesn't match design | Check UI Designer Agent output |
