# 🤖 Telegram Bot Setup - IN PROGRESS

## ✅ Completed

1. **Bot Code Created** - `functions/index.js`
   - All command handlers (/start, /link, /help, /unlink, /status)
   - Auto-link from deep links
   - Firestore integration
   - Error handling

2. **Dependencies Installed** - `functions/package.json`
   - telegraf: ^4.16.3
   - firebase-admin: ^13.7.0
   - firebase-functions: ^7.0.6

3. **Environment Configured** - `functions/.env`
   - TELEGRAM_BOT_TOKEN set

## ⚠️ BLOCKER: Firebase Plan Upgrade Required

### Problem:
Firebase Cloud Functions require **Blaze (Pay-as-you-go)** plan.

Current plan: **Spark (Free)** - Does NOT support Cloud Functions

### Solution:

**Option 1: Upgrade to Blaze Plan** (Recommended for Production)

1. Go to: https://console.firebase.google.com/project/repsync-app-8685c/usage/details
2. Click "Upgrade to Blaze"
3. Add payment method
4. Deploy function:
   ```bash
   firebase deploy --only functions:telegramWebhook
   ```

**Cost:** 
- First 125K invocations/month: FREE
- After that: $0.40 per 100K invocations
- For typical usage: ~$0-2/month

**Option 2: Use Alternative Hosting** (Free but more complex)

Host bot on:
- **Railway.app** - Free tier available
- **Render.com** - Free tier available  
- **Heroku** - Paid only now
- **VPS** - $5/month

---

## 📋 Manual Setup (After Upgrade)

### 1. Deploy Function

```bash
cd /Users/berloga/Documents/GitHub/flutter_repsync_app
firebase deploy --only functions:telegramWebhook
```

**Save the URL:**
```
https://us-central1-repsync-app-8685c.cloudfunctions.net/telegramWebhook
```

### 2. Set Webhook

```bash
curl -X POST "https://api.telegram.org/bot8607318703:AAE1RAcr38GMunRVVs831h2mk_XjdfC0Kb4/setWebhook?url=https://us-central1-repsync-app-8685c.cloudfunctions.net/telegramWebhook"
```

### 3. Verify Webhook

```bash
curl "https://api.telegram.org/bot8607318703:AAE1RAcr38GMunRVVs831h2mk_XjdfC0Kb4/getWebhookInfo"
```

**Expected Response:**
```json
{
  "ok": true,
  "result": {
    "url": "https://us-central1-repsync-app-8685c.cloudfunctions.net/telegramWebhook",
    "has_custom_certificate": false,
    "pending_update_count": 0
  }
}
```

### 4. Test Bot

1. Telegram → @repsyncbot
2. `/start`
3. Should get welcome message

---

## 🎯 Current Status

| Task | Status |
|------|--------|
| Bot code written | ✅ Complete |
| Dependencies installed | ✅ Complete |
| Token configured | ✅ Complete |
| Firebase plan upgrade | ⏳ **REQUIRED** |
| Function deployment | ⏳ Waiting for upgrade |
| Webhook setup | ⏳ Waiting for deployment |
| Testing | ⏳ Waiting for webhook |

---

## 🚀 Next Steps

1. **Upgrade Firebase plan** to Blaze (5 minutes)
2. **Run deploy command** (2 minutes)
3. **Set webhook** (1 minute)
4. **Test bot** (2 minutes)

**Total time after upgrade: ~10 minutes**

---

## 📞 Need Help?

After upgrading Firebase plan, run:

```bash
# Deploy
firebase deploy --only functions:telegramWebhook

# Set webhook
curl -X POST "https://api.telegram.org/bot8607318703:AAE1RAcr38GMunRVVs831h2mk_XjdfC0Kb4/setWebhook?url=<YOUR_FUNCTION_URL>"

# Test
# Open Telegram → @repsyncbot → /start
```

---

**Ready to deploy once Firebase plan is upgraded!** 🚀
