# Orchestration and review ledger

Hermes decomposed the research, handled P30 navigation and source verification, and wrote the synthesis. Worker outputs are retained verbatim as drafts. No worker was authorized to change application code.

## Task outcomes

| ID | Requested / observed model | Execution | Outcome / verification |
|---|---|---|---|
| L01 | `ollama/ornith-1.5:35b` | Native `delegate_task`, LAN endpoint | Failed immediately: HTTP 401 invalid/expired key. Runtime metadata confirms requested model; no successful inference. Hermes took over the four-file source analysis. No configuration/key changes made. |
| L02 | `ollama/ornith-1.5:35b` / same returned | Existing authenticated Studio client, bounded non-agentic worker, 180 s deadline | Nonempty final, stop finish, 25.75 s. Instrument matrix reviewed; corrections below. |
| L03 | `ollama/ornith-1.5:35b` / same returned | Same client, serial after L02, 180 s deadline | Nonempty final, stop finish, 20.15 s. Edge cases reviewed; corrections below. |
| L04 | `ollama/ornith-1.5:35b` / same returned | Same client, critique of the written proposal, 180 s deadline | Nonempty final, stop finish, 65.55 s. Useful clarifications applied: no-notes-in-loop behavior; provisional fretboard candidates; songless exercise boundaries. |
| O01 | `gpt-5.1-codex-mini` | Codex read-only, 240 s deadline | Failed: current ChatGPT account does not support this model. Exact error retained in O01-stderr.txt. No result fabricated. |
| O02 | `gpt-6-luna` / runtime header confirms | Codex read-only, low reasoning | Completed, exit 0, result file read. Selected after inspecting available local model metadata, which describes Luna as fast/affordable for easier tasks. No assumed API pricing or monetary savings claim. |
| C01 | `haiku` alias / `claude-haiku-5-5` in runtime usage | Claude CLI, Read-only allowed tools, 6 turns, 240 s deadline | Completed, exit 0, 42.34 s. Output read and checked against source; several overstatements rejected below. |

Local inference was prioritized for the bounded instrument matrix, edge cases and independent critique. Local workers were sequential to avoid contention. Cloud workers performed narrow independent source reviews. The native delegate 401 and unsupported OpenAI model are recorded failures, not successful subtasks. Direct Studio calls were authenticated through the already configured client without exposing or changing credentials; they were model workers, not tool-using child agents.

The outer process tools expose requested timeout separately from completion; O02's wall-clock ceiling was not independently verified, so no hard runtime guarantee is claimed for it. No unattended processes are required to continue this work.

## Orchestrator corrections

### Claude C01

- “Drum patterns sit outside the entry model” is false: `SongLabEntry.midi` stores them; full imports can carry both representations (`song_lab.dart:146-171`, `midi_song_import.dart:48-71`). Replaced with the narrower finding: separate UI/editing paths over related material.
- “Three import entry points, three gates” overstates it: full-MIDI buttons partly reuse `canImportMidi`/`pickAndImportMidi`; the legacy drum import is distinct. Keep shared full import, then make its entry behavior consistent rather than inventing a new importer.
- Repository is merge-enabled, not an unqualified whole-document replacement (`firestore_lab_repository.dart:70`). Stale supplied values/arrays can still overwrite newer state; this remains a concurrency risk, not a reproduced incident.
- Cancelling a pending debounce on dispose is source-confirmed, but current user data loss and playback interruption were not reproduced. They are explicit test gates, not device-pass claims.
- Do not implement “flush in dispose” mechanically: async persistence needs a verified ownership/error/lifecycle contract. The research proposes a regression requirement, not an untested patch.

### Ornith L02

- Drum grid uses lanes/rows, not necessarily “kit columns.” Its legacy storage does not encode arbitrary duration; do not promise all six views are lossless projections of the old drum format.
- Do not write every visual interaction back into musical data: selecting a keyboard range or candidate guitar position must be presentation-only.
- Replace “within tolerance” with an explicit event-preservation test for supported data; avoid silently allowing quantization drift.

### Ornith L03

- MIDI practice speed needs rescheduling/re-rendering, not necessarily audio time-stretch. No new time-stretch library is proposed.
- A recorded take should record the actual practice tempo as provenance, not erase it to match the canonical song tempo.
- Choosing an instrument view does not require voice reassignment. It changes neither timbre nor mix unless explicitly requested.
- Offline guarantees cover prepared/cached material, not all remote imports, saves or uncached files. Roles and alignment are reviewed/correctable, not guaranteed by auto-detection.

### OpenAI O02

The shared transport and attach side effects were verified directly in the cited providers. This is strong reuse evidence, but does not establish iOS parity or that all state is already unified. Its acceptance checks were incorporated rather than treated as executed tests.

## Operational lessons

A successful `/models` or load call does not prove a native delegated client uses valid credentials. A nonempty final and returned/runtime model are required. Track auth failure, unsupported model, timeout and empty final as distinct outcomes. One failed execution is not retried indefinitely; fallback is explicit and scoped.
