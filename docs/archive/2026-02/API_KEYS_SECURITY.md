# 🔐 API Keys Security Guide

## ✅ Secured Keys (in .env)

The following keys are now stored securely in `.env` file:

1. **Firebase API Key** - `FIREBASE_API_KEY`
2. **Spotify Client ID** - `SPOTIFY_CLIENT_ID`
3. **Spotify Client Secret** - `SPOTIFY_CLIENT_SECRET`
4. **Twitter API Key** - `TWITTER_API_KEY`
5. **Twitter API Secret** - `TWITTER_API_SECRET`
6. **Track Analysis API Key (RapidAPI)** - `TRACK_ANALYSIS_API_KEY`

## 📋 Setup Instructions

1. **Copy `.env.example` to `.env`:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` and add your real keys:**
   ```bash
   nano .env  # or use your favorite editor
   ```

3. **Never commit `.env` to git!**
   - `.env` is in `.gitignore`
   - Only commit `.env.example` with placeholder values

## 🔒 Why This Matters

- **Firebase API Key**: While not extremely sensitive (it's in your app code), it's best practice to keep it out of public repos
- **Spotify Credentials**: These ARE sensitive and should NEVER be committed
- **Twitter Credentials**: These ARE sensitive and should NEVER be committed
- **Track Analysis API Key**: This is your RapidAPI key - keep it secure to prevent unauthorized usage of your free tier quota (100 requests/month)

## 🚨 If You Accidentally Committed Keys

1. **Rotate the compromised key immediately**
2. **Remove from git history:**
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch .env" \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push:**
   ```bash
   git push origin --force --all
   ```

## 📱 Firebase Configuration

Firebase API key is loaded from `.env`:
```dart
final apiKey = dotenv.env['FIREBASE_API_KEY'] ?? 'fallback-key';
```

Fallback key is only for development. In production, always use `.env`.

## 🎵 Track Analysis API Setup

The app uses Track Analysis API (RapidAPI) for BPM and musical key detection.

**Get your free API key:**
1. Go to: https://rapidapi.com/soundnet-soundnet-default/api/track-analysis
2. Sign up for a free RapidAPI account
3. Subscribe to the free tier (100 requests/month)
4. Copy your API key
5. Add to `.env` file:
   ```
   TRACK_ANALYSIS_API_KEY=your_actual_key_here
   ```

**Without a valid key:**
- App will use 'demo' key with limited functionality
- Debug warnings will appear in console
- Production deployments should always use a real key

---

**Last Updated:** February 28, 2026
**Security Status:** ✅ All keys secured
