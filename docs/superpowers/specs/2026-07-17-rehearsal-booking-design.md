# Rehearsal scheduling → booking system: Epic 1 (regular users) + Epic 2 (studios)

## Context

FlowGroove's "arrange a rehearsal" flow (да/нет/не знаю poll → best time)
is being split into two adjacent epochs:

1. **Epic 1 — regular users**: modernize the existing in-app scheduling so
   it collects richer availability data and stops silently converging on
   one time.
2. **Epic 2 — studios**: a separate booking system for rehearsal spaces,
   starting with one pilot studio that requires **manual owner approval**
   (no auto-booking). Reddit/X research shows real pain on both sides:
   musicians can't find a studio with confirmed availability, don't know
   what equipment is actually working, and don't know who pays; studio
   owners lose slots to no-shows/last-minute cancels and drown in manual
   admin (email/DMs/phone).

Both epics share one continuous mental model so today's data already feeds
tomorrow's booking flow — no rebuild later.

**Codebase reality check:** the current implementation is already more
advanced than the original brainstorming notes assumed. `Rehearsal` already
has `requiredMemberUids`/`optionalMemberUids`, per-slot per-member voting
(`can`/`maybe`/`cant`), a scoring function that explains *why* a slot is
best (`lib/utils/rehearsal_scoring.dart`), and an explicit manual "Confirm
this time" step — the poll does **not** auto-pick a winner. So Epic 1 is a
gap-filling update, not a rebuild. Genuine gaps:

- No response deadline / no way to nudge stragglers.
- No structured venue field — `location` is a bare free-text string, so
  there's no seam for Epic 2 to hook into.
- **Zero notifications** fire on proposal-created or on confirmation (only
  a generic 24h-before Telegram reminder exists). This is the single
  biggest match to the researched pain ("chaotic messaging", the manual
  chasing both bands and studios complain about).
- `RehearsalVote.comment` field exists in the model and is serialized, but
  is dead — never read or written by any screen. The original ask
  ("предложить своё время") maps naturally onto reviving this field as a
  free-text counter-time suggestion, with zero data-model or
  security-rule changes.

## Epic 1 — Rehearsal Plan upgrade

### Data model — `lib/models/rehearsal.dart`

Two new nullable fields on `Rehearsal` (backward compatible, no migration):

- `responseDeadline` (`DateTime?`) — reuses the existing `_parseDateTime` /
  `_dateTimeToJson` helpers already in the file.
- `venueType` (`String?`, one of `undecided | custom | studio`) — new
  constants `venueUndecided/venueCustom/venueStudio`. When null, screens
  treat it as `custom` if `location` is set, else `undecided`. `studio` is
  a **placeholder value only** in Epic 1; nothing acts on it yet.

`RehearsalVote.comment` is revived as a "suggest a different time" free
text field — no model change needed.

### Edit screen — `lib/screens/bands/rehearsals/rehearsal_edit_screen.dart`

- Optional "Respond by" date+time picker alongside the existing time
  option pickers.
- Venue selector replacing the bare location field: `Not decided` /
  `Custom place` (reveals the location text field) / `Rehearsal studio`
  (disabled placeholder — the Epic 2 seam).

### Detail screen — `lib/screens/bands/rehearsals/rehearsal_detail_screen.dart`

- Deadline shown under the title; once passed, the "Waiting on" notice
  gains **Remind** (pings non-voters) and **Extend deadline** (deep-links
  to edit) actions.
- New "Suggestions" section surfacing any `RehearsalVote.comment` values.
- No "Continue without response" control — "Confirm this time" already
  covers that.

### Notifications — `functions/src/rehearsals.js`

Mirrors the existing `onBandSetlistCreated` pattern in
`functions/src/telegram/reminders.js`:

- `onRehearsalCreated` (Firestore `onCreate`) — notifies invited members a
  new proposal needs their vote.
- `onRehearsalConfirmed` (Firestore `onUpdate`, fires only on
  `collecting → confirmed`) — notifies invited members of the confirmed
  time/location.
- `remindRehearsalVoters` (`https.onCall`, editor/admin-only) — notifies
  only the not-yet-voted subset; backs the detail screen's Remind button.

All three use the existing `notifyBandMembers`/`sendToUser` helpers in
`functions/src/telegram/services/notifications.js` and are wired in
`functions/index.js`.

### Firestore rules

No changes — the rehearsal doc is already editor/admin-write-gated
(`firestore.rules:257-281`); the two new fields ride along with the
existing update rule, and `RehearsalVote.comment` is already part of the
member-owned vote doc.

## Epic 2 — Studio booking system (staged roadmap, spec only)

Source of truth stays FlowGroove/Firestore; Google Calendar is optional
export/import only, added no earlier than Stage 2. The Studio Portal is
**new routes inside the existing Flutter app** — there is no separate web
app shell to piggyback on (`build/web` *is* the Flutter Web build, single
`GoRouter`), so it's gated by the existing `ScreenBreakpoint` responsive
helpers, not a second app.

### Stage 1 — Pilot MVP (one studio, manual approval only)

- New models: `Studio` (id, name, address, ownerUids[], rooms[],
  openingHours, bookingMode='manual'), `Room` (id, studioId, name,
  capacity, equipment[], hourlyPrice), `BookingRequest` (id, rehearsalId,
  bandId, studioId, roomId, requestedSlots[], proposedSlot, confirmedSlot,
  message, status, createdAt, expiresAt).
  `BookingRequest.status`: `draft | awaiting_studio | action_needed |
  confirmed | declined | cancelled`.
- New Cloud Functions domain `functions/src/bookings/` (mirrors the
  `telegram/` subfolder convention): callables `createBookingRequest`,
  `confirmBooking`, `proposeAlternateTime`, `declineBooking`,
  `cancelBooking` — server-authoritative like `functions/src/bands.js`
  (client `allow write: if false`, mutation only through the Admin SDK)
  since approval needs to be atomic/audited.
- New Firestore collections `studios/{studioId}` and
  `bookingRequests/{id}`, rules following the existing
  server-authoritative + `isNotDemo()` conventions.
- Studio-owner is a **new role dimension** — a studio doc's `ownerUids[]`,
  checked the same denormalized-array way as `Band.adminUids`.
- Studio Portal: new routes (pushed on the root navigator, like the
  existing Metronome/Tuner "tool" screens) with two screens: Requests
  (New / Needs response / Confirmed / Past) and a simple weekly Schedule
  view — both read views over `BookingRequest`, not a standalone calendar
  server.
- Notifications: Telegram only at first (no FCM, no email infra exists in
  this repo today). New `functions/src/bookings/notifications.js`
  following the `notifyBandMembers`/`sendToUser` pattern.
- Entry point: once `venueType == venueStudio` is selected on a rehearsal,
  a "Find a rehearsal space" action creates a `BookingRequest` from the
  rehearsal's top slots + requirements.
- Counter-offer handling: studio proposes a new slot → if already covered
  by existing band availability, one-tap accept; otherwise a single
  yes/no mini-vote on just the new slot (no full re-vote).
- Explicitly deferred even within Stage 1: payments, auto-booking, studio
  ratings, CalDAV/own calendar server, syncing every tentative slot to
  Google Calendar (only the confirmed rehearsal is ever exported).

### Stage 2 — Studio-side calendar

- Studio marks recurring opening hours + ad-hoc closed intervals.
- Conflict checks against existing confirmed bookings for that room.
- Optional Google Calendar FreeBusy read (narrow scope, busy/free only)
  for external-conflict warnings — no write access to the studio's full
  calendar.
- Auto-record confirmed bookings into a FlowGroove-created secondary
  Google Calendar (`calendar.app.created` scope) if opted in.

### Stage 3 — Multiple studios

- Request a specific studio, or fan out one request to several studios in
  parallel.
- Filters: equipment, distance/radius, price, capacity.
- Studio response-time and reliability history surfaced per studio via
  separate signals (equipment-as-described, room-ready-on-arrival,
  response time, cleanliness) rather than one generic star rating.
- Waitlist: when a slot frees up, auto-notify only bands whose members are
  available, city/radius matches, room size and equipment fit — replacing
  the manual "post a discount and hope someone sees it" workflow studios
  described.

### Stage 4 — Partial automation + cost handling

- Per-studio booking mode: `Manual approval | Auto-approve trusted bands |
  Auto-book available slots`. Pilot studio stays on `Manual approval`
  indefinitely — a studio-level setting, never a global default.
- Deposit/cancellation policy as studio-level config (`No deposit | Fixed
  | Percentage | Full prepayment | New-clients-only | After-no-show-only`)
  — config surface only, no payment processing yet.
- Cost split: once a room has a price, show `total / participants` on the
  confirmed rehearsal — display only, no `Mark as paid`/debt tracking
  until this stage.
- No-show/cancellation-reason tracking feeding into the Stage 3
  reliability history.
