# 🔐 API Keys Security Guide

## ✅ Secured Keys (in .env)

The following keys are now stored securely in `.env` file:

1. **Firebase API Key** - `FIREBASE_API_KEY`
2. **Spotify Client ID** - `SPOTIFY_CLIENT_ID`
3. **Spotify Client Secret** - `SPOTIFY_CLIENT_SECRET`
4. **Twitter API Key** - `TWITTER_API_KEY`
5. **Twitter API Secret** - `TWITTER_API_SECRET`

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

---

**Last Updated:** February 28, 2026
**Security Status:** ✅ All keys secured
