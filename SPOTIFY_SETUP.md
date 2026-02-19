# Spotify API Setup Guide for RepSync

This guide explains how to configure and use the Spotify API integration in the RepSync Flutter app.

---

## Table of Contents

1. [Overview](#overview)
2. [Getting Spotify API Credentials](#getting-spotify-api-credentials)
3. [Configuration](#configuration)
4. [Testing the Integration](#testing-the-integration)
5. [Troubleshooting](#troubleshooting)
6. [Security Best Practices](#security-best-practices)
7. [Production Deployment](#production-deployment)

---

## Overview

The RepSync app integrates with the Spotify API to:
- Search for songs by title/artist
- Automatically fetch BPM (tempo) and musical key
- Populate song fields with accurate audio features

**Current Status:** ✅ Pre-configured for development

The app comes with pre-configured Spotify API credentials for development and testing. You can start using the Spotify integration immediately.

---

## Getting Spotify API Credentials

### Step 1: Create a Spotify Developer Account

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Log in with your Spotify account
3. If you don't have a Spotify account, create one at [spotify.com](https://www.spotify.com)

> **Note:** While you need a Spotify account to create a developer app, the API credentials work with both free and premium accounts. However, some features may require Premium.

### Step 2: Create an App

1. Click **"Create app"** or **"Create APP"** button
2. Fill in the required information:
   - **App name**: `RepSync` (or your preferred name)
   - **App description**: `Band repertoire management app`
   - **Redirect URI**: `https://berlogabob.github.io/flutter-repsync-app` (for production) or `http://localhost:8080/callback` (for local development)
   - **Website**: (optional) Your project website
   - Check the box to agree to the Developer Terms of Service

3. Click **"Save"** or **"Create"**

### Step 3: Get Your Credentials

1. Click on your app in the dashboard
2. Go to **Settings** tab
3. You'll see:
   - **Client ID**: A 32-character string (e.g., `92576bcea9074252ad0f02f95d093a3b`)
   - **Client Secret**: Click "View client secret" to reveal (e.g., `5a09b161559b4a3386dd340ec1519e6c`)

4. Copy both values - you'll need them for configuration

---

## Configuration

### Option A: Local Development (Recommended)

#### For Web Development

Edit `web/config.js`:

```javascript
// Flutter Web Environment Configuration
window.env = {
  "SPOTIFY_CLIENT_ID": "YOUR_CLIENT_ID_HERE",
  "SPOTIFY_CLIENT_SECRET": "YOUR_CLIENT_SECRET_HERE"
};
```

#### For Mobile/Desktop Development

Create or edit `.env` file in the project root:

```
# Spotify API Credentials
SPOTIFY_CLIENT_ID=YOUR_CLIENT_ID_HERE
SPOTIFY_CLIENT_SECRET=YOUR_CLIENT_SECRET_HERE
```

### Option B: Production Deployment

For production, use environment variables or a secure configuration management system:

1. **Firebase Hosting**: Add environment variables in Firebase Console
2. **Docker**: Use Docker secrets or environment variables
3. **CI/CD Pipeline**: Inject credentials during build process

### Current Pre-configured Credentials

For development convenience, the following credentials are pre-configured:

| Setting | Value |
|---------|-------|
| Client ID | `92576bcea9074252ad0f02f95d093a3b` |
| Client Secret | `5a09b161559b4a3386dd340ec1519e6c` |
| App Name | RepSync |
| Redirect URI | `https://berlogabob.github.io/flutter-repsync-app` |

---

## Testing the Integration

### Step 1: Run the App

```bash
# For web
flutter run -d chrome

# For mobile
flutter run
```

### Step 2: Navigate to Songs

1. Open the app
2. Go to the **Songs** tab
3. Tap the **+ (Add Song)** button

### Step 3: Search Spotify

1. Click the **"Search Spotify"** button
2. Enter a song title, e.g., `"Shape of You Ed Sheeran"`
3. Press Search

### Step 4: Verify Results

You should see search results with:
- Song title
- Artist name
- Album art
- **BPM** (tempo)
- **Key** (musical key in Camelot notation)

### Step 5: Select a Track

1. Tap on a track from the results
2. Verify that the following fields are populated:
   - Title
   - Artist
   - BPM
   - Key

### Expected Behavior

| Action | Expected Result |
|--------|-----------------|
| Search Spotify | Returns list of tracks with BPM/Key |
| Select Track | Fields populate automatically |
| Save Song | Song saved with Spotify data |

---

## Troubleshooting

### Issue: "Spotify not configured" Error

**Possible Causes:**
1. Credentials not set correctly
2. `.env` file not loaded
3. `web/config.js` not updated

**Solutions:**

1. **Verify credentials are set:**
   ```dart
   print('Spotify configured: ${SpotifyService.isConfigured}');
   print('Client ID: ${SpotifyService._clientId}');
   ```

2. **Check web config in browser console:**
   ```javascript
   console.log(window.env);
   ```

3. **Restart the app:**
   ```bash
   flutter clean
   flutter run -d chrome
   ```

### Issue: "Premium required" Error

**Cause:** The Spotify API app is linked to a free account.

**Solution:**
- Use a Spotify Premium account for the developer app
- Or, the pre-configured credentials should work for basic API access

### Issue: No BPM/Key in Results

**Possible Causes:**
1. API rate limit exceeded
2. Track doesn't have audio features
3. Network connectivity issue

**Solutions:**
1. Wait a few seconds and try again (rate limit: 100 requests/2 seconds)
2. Try a different, more popular track
3. Check your internet connection

### Issue: Search Returns Empty Results

**Possible Causes:**
1. Invalid query
2. API authentication failed

**Solutions:**
1. Try a simpler search term (e.g., just the song title)
2. Verify credentials are correct
3. Check Chrome DevTools console for errors

---

## Security Best Practices

### DO:

✅ **Keep credentials secure:**
- Never commit `.env` or `web/config.js` to version control
- These files are already in `.gitignore`

✅ **Use environment variables in production:**
- Inject credentials via CI/CD pipeline
- Use secret management services (AWS Secrets Manager, etc.)

✅ **Rotate credentials periodically:**
- Regenerate Client Secret in Spotify Dashboard
- Update your configuration

✅ **Monitor API usage:**
- Check Spotify Developer Dashboard for usage stats
- Set up alerts for unusual activity

### DON'T:

❌ **Don't hardcode credentials in source code:**
```dart
// BAD - Never do this
const clientId = "92576bcea9074252ad0f02f95d093a3b";
```

❌ **Don't share credentials publicly:**
- Don't post in forums, chat, or public repos
- Don't include in screenshots or logs

❌ **Don't use the same credentials across multiple projects:**
- Create separate apps for different projects
- Limits blast radius if compromised

---

## Production Deployment

### Before Deploying to Production

1. **Create your own Spotify app:**
   - Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
   - Create a new app under your organization
   - Get fresh Client ID and Secret

2. **Update Redirect URI:**
   - Set to your production domain
   - Example: `https://yourdomain.com/callback`

3. **Configure environment variables:**
   - Use your deployment platform's secret management
   - Examples:
     - Firebase Hosting: `firebase hosting:secrets:set SPOTIFY_CLIENT_ID`
     - Vercel: Add to project settings
     - Docker: Use secrets or env file

4. **Update web/config.js (if using static hosting):**
   - Generate config.js during build process
   - Don't commit the file with real credentials

### Example: Firebase Hosting Deployment

```bash
# Set secrets
firebase hosting:secrets:set SPOTIFY_CLIENT_ID
firebase hosting:secrets:set SPOTIFY_CLIENT_SECRET

# Deploy
flutter build web
firebase deploy
```

### Example: GitHub Pages Deployment

For GitHub Pages, you'll need to generate `web/config.js` during CI/CD:

```yaml
# .github/workflows/deploy.yml
- name: Create config.js
  run: |
    cat > web/config.js << EOF
    window.env = {
      "SPOTIFY_CLIENT_ID": "${{ secrets.SPOTIFY_CLIENT_ID }}",
      "SPOTIFY_CLIENT_SECRET": "${{ secrets.SPOTIFY_CLIENT_SECRET }}"
    };
    EOF
```

---

## API Reference

### Endpoints Used

| Endpoint | Purpose | Rate Limit |
|----------|---------|------------|
| `POST /api/token` | Get access token | 100 req/2s |
| `GET /v1/search` | Search tracks | 100 req/2s |
| `GET /v1/audio-features/{id}` | Get BPM/Key | 100 req/2s |

### Data Returned

**Search Results:**
- Track ID, Name, Artist, Album
- Album Art URL
- Duration
- Spotify URL

**Audio Features:**
- Tempo (BPM)
- Key (0-11, mapped to C, C#, D, etc.)
- Mode (Major/Minor)
- Time Signature
- Camelot Key notation (for DJs)

---

## Support

If you encounter issues:

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common problems
2. Review [Spotify API Documentation](https://developer.spotify.com/documentation/web-api)
3. Check Chrome DevTools Console for errors
4. Verify credentials in Spotify Developer Dashboard

---

**Last Updated:** February 19, 2026  
**Version:** 1.0
