/// Single source of the public event-share link (owner decision 2026-10-26:
/// canonical host is the web app origin).
const String eventShareOrigin = 'https://app.flowgroove.app';

/// `https://app.flowgroove.app/#/event?t=<id>.<secret>` — the hash form is the
/// one the router and already-shared links understand (legacy-compatible).
String eventShareUrl(String token) =>
    '$eventShareOrigin/#/event?t=${Uri.encodeQueryComponent(token)}';
