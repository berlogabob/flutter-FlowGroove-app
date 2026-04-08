// FlowGroove Web Configuration
// Generated at build time - DO NOT EDIT MANUALLY
// This file is loaded at runtime and should NEVER be committed to git
//
// SECURITY: This file contains sensitive credentials
// - For production: Use environment variables in CI/CD pipeline
// - For development: Use .env file with inject-web-config.sh script
// - Never commit this file with real credentials!

window.env = {
  // =============================================================================
  // FIREBASE CONFIGURATION
  // Get from: https://console.firebase.google.com
  // =============================================================================
  FIREBASE_API_KEY: '${FIREBASE_API_KEY}',

  // =============================================================================
  // SPOTIFY API CREDENTIALS
  // Get from: https://developer.spotify.com/dashboard
  // PRODUCTION: Use SPOTIFY_PROXY_URL instead of direct credentials
  // =============================================================================
  SPOTIFY_CLIENT_ID: '${SPOTIFY_CLIENT_ID}',
  SPOTIFY_CLIENT_SECRET: '${SPOTIFY_CLIENT_SECRET}',

  // =============================================================================
  // SPOTIFY PROXY (Recommended for Production)
  // When set, all Spotify API calls route through your secure backend
  // See: docs/SPOTIFY_PROXY_SETUP.md
  // =============================================================================
  SPOTIFY_PROXY_URL: '${SPOTIFY_PROXY_URL}',

  // =============================================================================
  // TWITTER/X API CREDENTIALS
  // Get from: https://developer.twitter.com/en/portal/dashboard
  // =============================================================================
  TWITTER_API_KEY: '${TWITTER_API_KEY}',
  TWITTER_API_SECRET: '${TWITTER_API_SECRET}',

  // =============================================================================
  // TRACK ANALYSIS API (RapidAPI)
  // Get from: https://rapidapi.com/soundnet-soundnet-default/api/track-analysis
  // Free tier: 100 requests/month
  // =============================================================================
  TRACK_ANALYSIS_API_KEY: '${TRACK_ANALYSIS_API_KEY}'
};

// =============================================================================
// VALIDATION HELPER (Development/Debug only)
// This code is removed in production builds via minification
// =============================================================================
if (typeof window !== 'undefined' && window.console && window.console.debug) {
  // Config loaded successfully - remove in production
  window.console.debug('FlowGroove config loaded');
}
