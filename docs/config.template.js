// FlowGroove Web Configuration
// Generated at build time - DO NOT EDIT MANUALLY
// This file is loaded at runtime and should NEVER be committed to git
//
// SECURITY: Web runtime config must contain only public or low-risk values.
// - Privileged third-party secrets stay in non-tracked local env or backend config
// - Web clients must use backend proxy endpoints for privileged API access
// - Never commit generated web/config.js

window.env = {
  // =============================================================================
  // FIREBASE CONFIGURATION
  // Get from: https://console.firebase.google.com
  // =============================================================================
  FIREBASE_API_KEY: '${FIREBASE_API_KEY}'

  // SPOTIFY_PROXY_URL and API_PROXY_URL used to live here. Spotify, Deezer and
  // lyrics.ovh are now reached only through the lookupTrackMetadata Cloud
  // Function, so the web client needs neither a Spotify proxy nor a CORS shim,
  // and this file publishes nothing about them.
};

// =============================================================================
// VALIDATION HELPER (Development/Debug only)
// This code is removed in production builds via minification
// =============================================================================
if (typeof window !== 'undefined' && window.console && window.console.debug) {
  // Config loaded successfully - remove in production
  window.console.debug('FlowGroove config loaded');
}
