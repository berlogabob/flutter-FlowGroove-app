# Environment Variables Setup Guide

## Overview

RepSync uses environment variables to store sensitive API credentials. This guide explains how to set them up for different platforms.

---

## Quick Start (Development)

### For Mobile/Desktop Development

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your credentials:**
   ```bash
   SPOTIFY_CLIENT_ID=your_actual_client_id
   SPOTIFY_CLIENT_SECRET=your_actual_client_secret
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

---

## For Web Development

### Option 1: Using `.env` file (Recommended for local development)

1. **Create `.env` file in project root:**
   ```bash
   SPOTIFY_CLIENT_ID=your_actual_client_id
   SPOTIFY_CLIENT_SECRET=your_actual_client_secret
   ```

2. **The `.env` file is automatically included as a Flutter asset**

3. **Run the app:**
   ```bash
   flutter run -d chrome
   ```

### Option 2: Using `web/config.js` (For production deployment)

1. **Copy the example file:**
   ```bash
   cp web/config.js.example web/config.js
   ```

2. **Edit `web/config.js` with your credentials:**
   ```javascript
   window.env = {
     "SPOTIFY_CLIENT_ID": "your_actual_client_id",
     "SPOTIFY_CLIENT_SECRET": "your_actual_client_secret"
   };
   ```

3. **Build and deploy:**
   ```bash
   flutter build web
   ```

---

## Getting Spotify API Credentials

1. **Go to Spotify Developer Dashboard:**
   https://developer.spotify.com/dashboard

2. **Log in with your Spotify account**

3. **Create a new app:**
   - Click "Create app"
   - Fill in app name and description
   - Accept terms and conditions
   - Click "Save"

4. **Get your credentials:**
   - Click on your app
   - Go to "Settings"
   - Copy "Client ID" and "Client Secret"

5. **Add credentials to your environment:**
   - For mobile/desktop: Add to `.env` file
   - For web: Add to `web/config.js` or `.env` file

---

## Production Deployment

### Firebase Hosting

1. **Set environment variables in Firebase:**
   ```bash
   firebase functions:config:set \
     spotify.client_id="your_client_id" \
     spotify.client_secret="your_client_secret"
   ```

2. **Or use Firebase Hosting environment variables:**
   Create `.env` file in `public/` directory after build

### Alternative: Build-time Environment Variables

For CI/CD pipelines, you can inject environment variables at build time:

```bash
# Example for GitHub Actions
SPOTIFY_CLIENT_ID=${{ secrets.SPOTIFY_CLIENT_ID }} \
SPOTIFY_CLIENT_SECRET=${{ secrets.SPOTIFY_CLIENT_SECRET }} \
flutter build web
```

---

## Security Best Practices

### ✅ DO:

- Use environment variables for all sensitive data
- Add `.env` to `.gitignore` (already done)
- Use different credentials for development and production
- Rotate credentials regularly
- Use secrets management in CI/CD

### ❌ DON'T:

- Commit `.env` files to version control
- Hardcode credentials in source code
- Share credentials via email/chat
- Use production credentials in development

---

## Troubleshooting

### Error: `.env` file not found

**Solution:**
```bash
# Create .env file from example
cp .env.example .env

# Edit with your credentials
nano .env  # or use your preferred editor
```

### Error: `SPOTIFY_CLIENT_ID` is empty

**Solution:**
1. Check that `.env` file exists
2. Verify credentials are correct (no extra spaces)
3. Run `flutter clean` and `flutter pub get`
4. Restart your IDE

### Web: Environment variables not loading

**Solution:**
1. Check that `.env` is listed in `pubspec.yaml` assets
2. Verify `web/config.js` exists (if using that method)
3. Check browser console for errors
4. Clear browser cache

---

## File Locations

| File | Purpose | Committed to Git? |
|------|---------|-------------------|
| `.env` | Environment variables (dev) | ❌ No (in .gitignore) |
| `.env.example` | Template for `.env` | ✅ Yes |
| `web/config.js` | Web environment variables | ❌ No (in .gitignore) |
| `web/config.js.example` | Template for web config | ✅ Yes |

---

## Verification

To verify environment variables are loaded correctly:

### For Mobile/Desktop:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

print('Client ID: ${dotenv.env['SPOTIFY_CLIENT_ID']}');
// Should print your client ID (not 'your_client_id_here')
```

### For Web:
Open browser console and type:
```javascript
console.log(window.env);
// Should show your environment variables
```

---

## Additional Resources

- [Flutter Dotenv Package](https://pub.dev/packages/flutter_dotenv)
- [Spotify API Documentation](https://developer.spotify.com/documentation/web-api)
- [Firebase Environment Variables](https://firebase.google.com/docs/functions/config-env)

---

**Last Updated:** February 19, 2026  
**Version:** 1.0
