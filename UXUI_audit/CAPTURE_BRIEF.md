# FlowGroove screenshot capture brief (for codex)

You are driving a REAL Android phone over adb to screenshot every screen, menu, popup, bottom sheet, and dialog of the FlowGroove app (package `com.flowgroove.app`). Work from the repo root `/Users/berloga/Documents/GitHub/flutter_repsync_app`.

## Device
- adb: `~/Library/Android/sdk/platform-tools/adb`
- serial: `000251565001005` (always pass `-s 000251565001005`)
- screen: 1260x2800, dark theme app
- The app is already open and logged in. Do NOT reinstall, clear data, or sign out.

## Loop
1. `~/Library/Android/sdk/platform-tools/adb -s 000251565001005 exec-out screencap -p > UXUI_audit/screenshots/<NN>_<screen>__<state>.png`
2. LOOK at the screenshot you just saved (view the image file) before deciding the next action. Never tap blind.
3. Navigate with `adb shell input tap X Y`, back with `adb shell input keyevent 4`, scroll with `adb shell input swipe 630 2000 630 800 300`.
4. After every navigation tap, wait ~1.5s (`sleep 1.5`) before the screencap.

## Naming
`NN_<screen>__<state>.png` — zero-padded two-digit index in capture order, kebab-case screen name matching the checklist, `__<state>` for menus/popups/scrolled views. Examples: `03_songs__list.png`, `04_songs__filters-popup.png`, `12_edit-song__structure-editor.png`, `15_bands__list__scroll2.png`. The probe `00_probe.png` already exists (Home).

Append one line per file to `UXUI_audit/screenshots/INDEX.md` as you go: `- 03_songs__list.png — Songs tab, default list`.

## SAFETY — HARD RULES (real user data)
- NEVER tap anything labeled Delete, Remove, Sign out, Log out, Leave band, or a trash icon's confirmation. If a destructive confirmation dialog appears: screenshot it, then tap Cancel or press back.
- NEVER confirm any dialog that changes data. Screenshot → Cancel/back.
- Do NOT type into forms. Opening create/edit screens is fine; screenshot them empty/prefilled and back out. If backing out asks "discard changes?" — screenshot, then choose Discard (discarding is safe, saving is not).
- Do NOT send invites, do NOT join/leave anything, do NOT start purchases.
- Do NOT sign out to capture auth screens — skip them and note it in INDEX.md.

## Checklist (capture each screen + every ⋮/kebab menu, filter popup, bottom sheet, tab, and dialog you find on it)
Bottom nav tabs: Home, Songs, Bands, Setlists, Profile.

1. **Home** — done (00_probe.png), but also capture: the `...` menu top-right.
2. **Songs tab** — list; tag filter row states; the Filters (Key/BPM) popup; a song card ⋮ menu; the quick-action / practice picker if present; scrolled list.
3. **Song detail / edit** — open one song: edit screen (scroll for all of it), structure/sections editor, performance sheet / practice view, its ⋮ menu.
4. **Add song** — the add-song screen (from Home "+ Song" or Songs tab), including the autofill/search suggestions state if it shows without typing (do not save).
5. **Song Bank** (Home quick action) and **song duplicates/merge** screen if reachable read-only.
6. **Bands tab** — list; each visible menu; open ONE band: band detail and all its tabs/sections — songs, setlists, about, invite (do NOT send), members, rehearsals; a rehearsal detail; the create-rehearsal screen (back out, discard).
7. **Create band** screen (back out, discard). **Join band** screen if reachable from UI.
8. **Setlists tab** — list; open the setlist; its edit screen; export/PDF menu if present (do not actually share); create-setlist screen (back out).
9. **Profile tab** — full screen (scroll to bottom where Sign Out / Delete account live — screenshot them, DO NOT TAP); any menus.
10. **Metronome** and **Tuner** (Home → Tools).
11. Anything else you encounter: onboarding hints, snackbars, empty states, error states — screenshot and index them.

## Done criteria
- Every checklist item has ≥1 screenshot; every menu/popup you could open non-destructively is captured.
- `UXUI_audit/screenshots/INDEX.md` lists every file with a one-line description, plus a final "Skipped/blocked" section (e.g. auth screens).
- Finish by returning the app to the Home tab.
