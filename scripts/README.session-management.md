# Session Management Scripts

**Location:** `scripts/session-start.sh` and `scripts/session-end.sh`

---

## 🚀 Quick Start

### End Current Session
```bash
./scripts/session-end.sh "What you accomplished"
# Example:
./scripts/session-end.sh "Fixed deployment credential injection"
```

### Start New Session
```bash
./scripts/session-start.sh "Your goal"
# Example:
./scripts/session-start.sh "Fix theme compliance violations"
```

---

## 📋 What Each Script Does

### `session-end.sh`

When you finish a work session, this script:

1. **Exports Chat Context** - Saves conversation reference
2. **Saves Session State** - Creates `.qwen/SESSION_STATE.md` with:
   - Current branch
   - Recent commits
   - Open tasks
   - Modified files
3. **Creates Next Session Context** - Generates `.qwen/NEXT_SESSION.md` with:
   - Carry-over tasks
   - Current focus
   - Agents to wake
   - Files to review
4. **Cleans Up** - Removes temporary files (*.bak, *.tmp, .DS_Store)
5. **Commits Artifacts** - Optional commit of session state

**Generated Files:**
- `.qwen/SESSION_STATE.md` - Snapshot of current state
- `.qwen/NEXT_SESSION.md` - Context for next session

---

### `session-start.sh`

When you start a new work session, this script:

1. **Loads Previous Context** - Reads `.qwen/NEXT_SESSION.md`
2. **Shows QWEN.md Patterns** - Displays recent session completions
3. **Checks Session State** - Shows last session end time
4. **Git Status Check** - Shows branch and uncommitted changes
5. **Sets Session Goal** - Records what you're working on
6. **Activates Agent Team** - Shows available specialist agents
7. **Creates Tracking File** - Generates `.qwen/ACTIVE_SESSION.md`

**Generated Files:**
- `.qwen/ACTIVE_SESSION.md` - Live session tracking

---

## 📁 Files Created

```
.qwen/
├── ACTIVE_SESSION.md      # Current session tracking (created by start)
├── SESSION_STATE.md       # Previous session snapshot (created by end)
└── NEXT_SESSION.md        # Context for next session (created by end)
```

---

## 🔄 Typical Workflow

### Morning (Start Session):
```bash
# Start new session with your goal
./scripts/session-start.sh "Add user authentication"

# Script will:
# - Show previous session context
# - Display current git status
# - Ask about uncommitted changes
# - Create active session tracking
```

### During Session:
- Work normally with Qwen
- Use specialist agents as needed
- Track tasks with `todo_write` tool

### Evening (End Session):
```bash
# End session with what you accomplished
./scripts/session-end.sh "Added login screen and auth provider"

# Script will:
# - Save session state
# - Create next session context
# - Clean up temp files
# - Optionally commit artifacts
```

---

## 💡 Best Practices

### ✅ DO:
- Run `session-end.sh` at the end of each work session
- Review `NEXT_SESSION.md` before starting
- Keep session goals specific and achievable
- Use the optional commit feature to track progress

### ❌ DON'T:
- Skip session-end (you'll lose context)
- Ignore carry-over tasks in NEXT_SESSION.md
- Start multiple sessions without ending previous
- Delete `.qwen/` directory (contains session history)

---

## 🎯 Example Session Flow

### Day 1 - Morning:
```bash
$ ./scripts/session-start.sh "Fix metronome audio bugs"

# Output shows:
# - No previous session context (first session)
# - Current branch: feature/metronome-optimization
# - Working tree clean
# - Session goal: Fix metronome audio bugs
# - Active session tracking created
```

### Day 1 - Work:
- Fix audio focus manager
- Add tone configuration
- Update metronome providers

### Day 1 - Evening:
```bash
$ ./scripts/session-end.sh "Fixed metronome audio bugs"

# Output shows:
# - Session state saved
# - Next session context created
# - Temp files cleaned
# - Session artifacts committed
```

### Day 2 - Morning:
```bash
$ ./scripts/session-start.sh "Add accent pattern editor"

# Output shows:
# - Previous session: Fixed metronome audio bugs
# - Carry-over tasks from NEXT_SESSION.md
# - Current branch: feature/metronome-optimization
# - New session tracking created
```

---

## 🔧 Customization

### Edit Session Templates:
- `.qwen/agents/` - Specialist agent configurations
- `QWEN.md` - Project memory and patterns

### Modify Scripts:
- Add custom cleanup rules in `session-end.sh`
- Add custom checks in `session-start.sh`
- Change commit message format

---

## 📊 Session Artifacts

### SESSION_STATE.md Format:
```markdown
# Session State - 2026-04-01

**Session Ended:** 2026-04-01 18:30:00
**Session Description:** Fixed deployment credential injection

## Current Branch
second01

## Recent Commits
abc1234 chore: Add missing assets
def5678 fix: Add docs/main.dart.js

## Open Tasks
- [ ] TODO: Add any incomplete tasks here

## Files Modified This Session
 M Makefile
 M scripts/inject-web-config.sh

## Agent Status
- All agents: STANDBY
- Active tasks: NONE
```

### NEXT_SESSION.md Format:
```markdown
# Next Session Context

**Previous Session:** 2026-04-01
**Previous Session Description:** Fixed deployment credential injection

## Carry-Over Tasks
- [ ] Test deploy-stable with real FTP credentials

## Current Focus
- Verify production deployment works

## Important Context
- .env file must have FTP credentials
- web/config.js auto-generated now

## Branch Status
Current branch: second01
Last commit: abc1234 chore: Add missing assets

## Agents to Wake
- [x] mr-senior-developer (code review)
- [ ] mr-tester (testing)
```

---

## 🎁 Benefits

Using these scripts gives you:

1. **Continuity** - Pick up where you left off
2. **Context Preservation** - Never lose important details
3. **Task Tracking** - Clear view of what's done/pending
4. **Agent Efficiency** - Wake only needed agents
5. **Progress History** - See what you accomplished
6. **Clean Boundaries** - Clear start/end to sessions

---

**Remember:** Consistent use of these scripts creates a sustainable development workflow with perfect context preservation between sessions! 🎉
