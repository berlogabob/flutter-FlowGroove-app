# Rules for coding agents (FlowGroove)

These rules apply to every agent and every task in this repo. A task brief can narrow them, never loosen them.

## Design system
1. Use tokens only: colours `MonoPulseColors` / `context.mp`, spacing `MonoPulseSpacing`, radius `MonoPulseRadius`,
   text `MonoPulseTypography` (`lib/theme/`). No raw numbers for padding, gaps, radius or font size, and no
   `Color(0x…)` or `Colors.*` in `lib/`. The only exception is a line ending in `// ds-allow: <reason>`.
2. Reuse the widgets in `lib/widgets/` (CustomButton, AppCard, AppFilterChip, AppBadge, SectionHeader, EmptyState,
   ErrorBanner, LoadingIndicator, …). Extend an existing widget instead of writing a look-alike.
3. Stable layout S1–S5 (`design/figcraft/SPEC.md`, "Stable layout"): a state change never changes geometry.
4. The FigCraft spec (`design/figcraft/specs/<screen>.json`) is the contract for a screen. Code follows the spec.
   Agents never edit a spec or `design/tokens/tokens.json` to match their code; design changes need the user's
   approval and a `Design-Approved: <who, when>` line in the commit message.

## Gates
5. Never edit gate files: `design/ratchets.json`, `design/parity_lock.txt`, `design/stable_layout_allow.txt`,
   `scripts/check_stable_layout.py`, `design/gate_guard.py`, `AGENTS.md`. Guard code (`design/diff_lint.py`,
   `design/ratchet.py`, `design/metrics.py`, `.githooks/*`, `scripts/plan_run.py`, the design targets in `Makefile`,
   `.github/workflows/checks.yml`) changes only when your task names the file, and only to make a check stricter.
6. Never delete, weaken or skip a test assertion.
7. Before you finish: run the tests of the files you changed (`scripts/ftest.sh <test files>`), and
   `make design-guard` when that target exists.

## Repo
8. Change only the files your task names. No new packages unless the task says so.
9. Public repo: no personal names, emails, local paths, screenshots or secrets (`.env`, `key.properties`,
   `*.keystore`, `.ftp-env`).
