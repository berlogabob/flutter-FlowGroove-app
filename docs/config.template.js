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
  FIREBASE_API_KEY: '${FIREBASE_API_KEY}',

  // =============================================================================
  // SPOTIFY PROXY (Recommended for Production)
  // When set, all Spotify API calls route through your secure backend
  // See: docs/SPOTIFY_PROXY_SETUP.md
  // =============================================================================
  SPOTIFY_PROXY_URL: '${SPOTIFY_PROXY_URL}',

  // =============================================================================
  // API PROXY (CORS shim for public no-auth APIs: Deezer, lyrics.ovh)
  // Web can't call those hosts directly (no CORS header); when set, autofill
  // routes them through this Cloud Function. No secret involved.
  // =============================================================================
  API_PROXY_URL: '${API_PROXY_URL}'
};

// =============================================================================
// VALIDATION HELPER (Development/Debug only)
// This code is removed in production builds via minification
// =============================================================================
if (typeof window !== 'undefined' && window.console && window.console.debug) {
  // Config loaded successfully - remove in production
  window.console.debug('FlowGroove config loaded');
}
