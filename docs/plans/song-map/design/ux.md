# Song Map UX (input for design tasks)

One screen replaces the practice wizard + region list + pad banks. Phone frame 412x915, Light and Dark.

Zoom levels (one timeline, 3 levels):
- SONG: whole song. Section lane (coloured blocks with name, e.g. "Intro", "Chorus 1"; repeats share colour + letter A/B/C)
  above the waveform; bar ruler below (1, 9, 17 ...); playhead. Pads = sections.
- SECTION (double-tap a section block): that section + 1 bar each side. Minimap strip at top (whole song, viewport
  window). Breadcrumb "Song › Chorus 1". Parts lane (a/b/a/b blocks, 2/4/8 bars) under the waveform, bar numbers each
  bar, boundary handles (drag along bars). Pads = parts + "Whole section".
- PART (double-tap a part or boundary): beat grid 1 . 2 . 3 . 4, boundary nudge ◀ beat ▶, "Listen across" button
  (plays 2 bars before -> 2 bars after the seam). Pads = parts.
Header: song title, tempo chip ("170 BPM ✓" or warning "80.49 BPM"), Edit toggle.
Context bar (when a boundary is selected): "Bar 36 · 1:04.5", ◀ ▶, Listen across, Delete, Split at playhead.
Review state (after "Analyze song"): new boundaries dashed, banner "9 sections found · check, then Done"; re-analysis
  keeps old map, banner "New map: Keep old / Use new".
Tempo banner (off-whole tempo): "Audio runs at 80.49 BPM · Stretch to 80 / Keep".
Transport bar (always visible, bottom): Play/Stop, Loop toggle, speed chip "75%", count-in, click, "click & drums".
Range button in the pad header: tap first pad, then last pad -> loop range.

Pad states (must be obvious at arm's length, both themes):
- Idle: surface background, section colour as a 6 dp left stripe, label + bar count ("Chorus 1 · 16 bars").
- Selected (not playing): 3 dp border in textPrimary.
- Playing: solid accentOrange fill, charcoal text, play icon, 4 dp progress bar at the bottom (loop position).
- Queued (starts at next bar): 3 dp accentOrange border + small "next" label.
- Disabled: 38% opacity.
Section block on the timeline mirrors Selected/Playing (Playing = accentOrange outline 3 dp + darker tint).
Never signal state with a white outline on a bright colour (that is the bug being fixed).

## Review fixes (SD7, 2026-11-20)
- Section lane: block width proportional to its bars. Label rule: show the full name when the block is >= 64 dp wide,
  otherwise only the letter (never a truncated "Pa.."). Same rule in code.
- Pad subtitle = bar count ("8 bars" or "8 bars · Bars 1-8"), not the word "Section".
- Waveform: frames show a simple waveform shape (vertical bars), not an empty box.
- Range across sections happens at SONG level (pads = sections); at SECTION level the range is across parts.
