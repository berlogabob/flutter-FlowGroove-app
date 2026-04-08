# 🔄 SEQUENTIAL WORKFLOW PROTOCOL

## Philosophy: Self-Organizing Agent System

Agents do NOT have pre-assigned permanent roles. Instead, the system operates on a **sequential protocol** where agents self-organize based on task context, previous outputs, and mission alignment.

---

## 🎯 CORE PRINCIPLES

### 1. **Dynamic Role Assignment**
- Agents invent their own roles per task (or decline participation)
- No permanent specialization — roles shift based on needs
- Example: `mr-architect` might become "API integration specialist" for one task, then "state management reviewer" for another

### 2. **Voluntary Participation**
- Each agent receives full context:
  - Original user request
  - Team mission & goals
  - All previous agent outputs
- Agent then decides:
  - ✅ "I'll take role [X] and execute [Y]"
  - ❌ "I add no value here — passing to next"

### 3. **Sequential Context Passing**
```
Agent N receives:
├── User's original request
├── Mission statement
├── Outputs from Agent 1 to N-1
└── Available slots for next agents

Agent N produces:
├── Self-defined role
├── GOST-formatted output
├── Issues/blockers (if any)
└── Recommended next agent(s)
```

### 4. **Spontaneous Hierarchy**
- System naturally deepens hierarchy as task complexity grows
- No external instructions needed — agents coordinate organically
- Simple task → 2-3 agents
- Complex task → 5-7 agents with sub-roles

---

## 📋 WORKFLOW EXECUTION

### Step 1: Task Reception
```
User Request → mr-supervisor (coordinator) → Sequential chain begins
```

### Step 2: Agent Self-Organization
When activated, each agent MUST:

1. **Read full context** (user request + all previous outputs)
2. **Analyze what's done** (identify gaps, needs, opportunities)
3. **Invent own role** (or decline):
   ```markdown
   ## ROLE DECLARATION
   **Agent:** [agent-name]
   **Self-Defined Role:** [what I'll do for this task]
   **Reason:** [why this adds value]
   **Decline Reason:** [if skipping - why I add no value]
   ```
4. **Execute work** (produce GOST output)
5. **Recommend next agent** (who should continue)

### Step 3: Sequential Execution Order
```
mr-supervisor (initiates chain)
    ↓
Agent 1 (self-organizes)
    ↓
Agent 2 (reads Agent 1 output, self-organizes)
    ↓
Agent 3 (reads Agent 1+2 outputs, self-organizes)
    ↓
... continues until task complete
    ↓
mr-quality-control (final gate)
    ↓
mr-supervisor (session end protocol)
```

### Step 4: Chain Termination
Chain ends when:
- ✅ All user requirements met
- ✅ Quality gates passed
- ✅ Next agent writes: "No further agents needed — task complete"

---

## 🧩 AGENT SELF-ORGANIZATION TEMPLATE

Every agent MUST use this format when activating:

```markdown
## 🤖 AGENT ACTIVATION: [Agent Name]

### Context Analysis
**What's Done:**
- [List previous agent outputs]

**What's Missing:**
- [Identify gaps]

**My Self-Defined Role:**
- [What I'll do]

### Execution (GOST Format)

**Goal:** [What needs to be achieved]
**Outcome:** [What I did]
**Status:** ✅ Done / 🟡 In Progress / 🔴 Blocked
**Next:** [Recommended next agent + why]
**Issues:** [Blockers/risks]

### Decision
✅ **I'm participating** — Role: [X]
❌ **I'm declining** — Reason: [I add no value because Y]
```

---

## 🎭 EXAMPLE: Sequential Workflow in Action

### User Request:
"Build a Hugo landing page with blog"

### Chain Execution:

**1. mr-supervisor:**
```
## GOST: mr-supervisor - Sequential Init

**Goal:** Initiate sequential workflow for Hugo landing page
**Outcome:** Activated chain, passing to Agent 1
**Status:** ✅ Done
**Next:** mr-hugo (needs Hugo site structure)
**Issues:** None
```

**2. mr-hugo:**
```
## 🤖 AGENT ACTIVATION: mr-hugo

### Context Analysis
**What's Done:** User request documented
**What's Missing:** Hugo site structure, config, content
**My Self-Defined Role:** Hugo Site Architect

### Execution (GOST Format)

**Goal:** Initialize Hugo site with PaperMod theme
**Outcome:** Created site/ directory, hugo.toml, content structure
**Status:** ✅ Done
**Next:** mr-content (needs to write landing page copy)
**Issues:** None

### Decision
✅ I'm participating — Role: Hugo Site Architect
```

**3. mr-content:**
```
## 🤖 AGENT ACTIVATION: mr-content

### Context Analysis
**What's Done:** Hugo site initialized
**What's Missing:** Landing page copy, hero text, FAQ, blog posts
**My Self-Defined Role:** Conversion Copywriter

### Execution (GOST Format)

**Goal:** Write high-converting landing page content
**Outcome:** Created hero text, features grid, FAQ, 2 blog posts
**Status:** ✅ Done
**Next:** mr-seo (needs to optimize for search)
**Issues:** None

### Decision
✅ I'm participating — Role: Conversion Copywriter
```

**4. mr-seo:**
```
## 🤖 AGENT ACTIVATION: mr-seo

### Context Analysis
**What's Done:** Hugo site + content complete
**What's Missing:** SEO meta tags, OpenGraph, sitemap, analytics
**My Self-Defined Role:** SEO & Analytics Specialist

### Execution (GOST Format)

**Goal:** Maximize search visibility & track behavior
**Outcome:** Added GA4, Clarity, OpenGraph, sitemap, schema.org
**Status:** ✅ Done
**Next:** mr-quality-control (task complete, needs final review)
**Issues:** None

### Decision
✅ I'm participating — Role: SEO & Analytics Specialist
```

**5. mr-quality-control:**
```
## GOST: mr-quality-control - Final Gate

**Goal:** Validate all deliverables
**Outcome:** All checks passed (structure, content, SEO, analytics)
**Status:** ✅ Done
**Next:** mr-supervisor (session end)
**Issues:** None

### Decision
✅ Task complete — no further agents needed
```

---

## ⚡ BEST PRACTICES FOR SEQUENTIAL WORK

### ✅ DO:
- Read ALL previous outputs before acting
- Be specific in self-defined role
- Decline if you add no value (saves tokens, improves quality)
- Recommend next agent with clear reasoning
- Use GOST format every time
- Identify blockers early

### ❌ DON'T:
- Duplicate previous agent's work
- Expand scope beyond user request
- Skip context reading
- Force participation when unnecessary
- Ignore previous outputs
- Break sequential order

---

## 🔗 INTEGRATION WITH EXISTING AGENT SYSTEM

### Hierarchy (Modified):
```
USER (Final Authority)
  ↓
mr-supervisor (Chain Initiator & Final Authority)
  ↓
Sequential Chain:
  Agent 1 → Agent 2 → Agent 3 → ... → Agent N
  ↓
mr-quality-control (Final Gate)
  ↓
mr-supervisor (Session End Protocol)
```

### Rules That Still Apply:
- ✅ Rule 1: User Request Required
- ✅ Rule 2: No Direct Code Modification (unless designated agent)
- ✅ Rule 3: GOST Format Required
- ✅ Rule 4: Quality Gates (enforced by mr-quality-control)
- ✅ Rule 5: Documentation
- ✅ Rule 6: Agent Hierarchy

### New Rules for Sequential Workflow:
- **Rule 7:** Agents MUST self-organize (no waiting for assignment)
- **Rule 8:** Agents MUST read full context before acting
- **Rule 9:** Agents CAN decline participation (with reason)
- **Rule 10:** Sequential order CANNOT be skipped (Agent N needs N-1 output)
- **Rule 11:** mr-supervisor monitors chain health (can inject/cancel agents)

---

## 📊 SEQUENTIAL WORKFLOW METRICS

| Metric | Target | Why It Matters |
|--------|--------|----------------|
| Chain Length | 3-6 agents | Too short = gaps, too long = waste |
| Decline Rate | 20-40% | Healthy system self-regulates |
| Token Efficiency | <50k per chain | Cost control |
| Completion Rate | ≥95% | Chains should finish |
| Quality Score | ≥95% | mr-quality-control approval |

---

## 🚨 ESCALATION PROTOCOL

### Chain Stalls (Agent Doesn't Act):
```
Wait 5 min → mr-supervisor intervenes → Reassign or skip
```

### Agent Expands Scope:
```
mr-supervisor blocks → Warns agent → Resets to user request
```

### Quality Gate Fails:
```
mr-quality-control blocks → Returns to specific agent → Fix required
```

### Chain Too Long (>8 agents):
```
mr-supervisor intervenes → Consolidates roles → Shortens chain
```

---

## 🎯 ACTIVATION TRIGGERS

### Automatic:
- User request with clear task
- Phase completion in roadmap
- mr-supervisor activation
- Quality gate failure requiring fix

### Manual:
- User explicitly requests sequential workflow
- mr-supervisor initiates chain
- Agent escalation requires continuation

---

## 📝 DOCUMENTATION REQUIREMENTS

Every sequential chain MUST produce:
1. **Chain Summary** (in session notes):
   - Agents activated
   - Roles self-defined
   - Final outcome
2. **GOST Outputs** (from each agent)
3. **Quality Gate Report** (from mr-quality-control)
4. **Session End Protocol** (from mr-supervisor)

---

## 🔮 FUTURE ENHANCEMENTS

- [ ] Agent performance tracking across chains
- [ ] Automatic role suggestion based on task type
- [ ] Chain optimization (skip unnecessary agents)
- [ ] Parallel sub-chains for independent tasks
- [ ] Machine learning for role prediction

---

**Created:** 2026-04-08  
**Version:** 1.0  
**Status:** ✅ Active  
**Approved by:** User request (Sequential workflow implementation)
