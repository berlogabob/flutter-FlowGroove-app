# FlowGroove Telegram Bot - Support Group Edition

Modern Telegram bot with **Support Group + Topics** functionality.

## Features

### For Users:
- ✅ Link Telegram account to FlowGroove
- ✅ Automatic personal support topic creation
- ✅ Direct messaging to support team
- ✅ Account status checking
- ✅ Unlink functionality

### For Support Team:
- ✅ Forum-style topics (one per user)
- ✅ Admin commands for topic management
- ✅ Reply to users from support group
- ✅ Close/reopen topics
- ✅ Admin-only commands

## Quick Start

### 1. Install Dependencies

```bash
cd telegram_bot
pip install -r requirements.txt
```

### 2. Create Support Group

1. Create **New Group** in Telegram
2. Add your bot as **member**
3. Make bot an **admin** (required for topic management)
4. Enable **Forum** feature:
   - Group Settings → Topics → Enable
5. Get **Group ID**:
   - Forward message from group to @userinfobot
   - Copy the ID (starts with `-100`)

### 3. Configure

Edit `.env`:
```env
TELEGRAM_BOT_TOKEN=your_bot_token_here
FIREBASE_CREDENTIALS=serviceAccountKey.json

# Support Group (from step 2)
SUPPORT_GROUP_ID=-1001234567890
GENERAL_TOPIC_ID=1
ANNOUNCEMENTS_TOPIC_ID=2

# Admin IDs (your Telegram user ID)
ADMIN_IDS=123456789,987654321
```

### 4. Firebase Service Account

1. Firebase Console → Project Settings
2. Service Accounts → Generate New Private Key
3. Save as `serviceAccountKey.json` in `telegram_bot/`

### 5. Run Bot

**Local Testing:**
```bash
python bot/main.py
```

**Production (Webhook):**
```bash
# Set in .env
WEBHOOK_URL=https://your-domain.com/webhook

# Run with web server
gunicorn bot.main:app
```

## Usage

### User Commands:

- `/start` - Welcome + create support topic
- `/start <user_id>` - Welcome + link account
- `/link <user_id>` - Link Telegram to FlowGroove
- `/unlink` - Unlink account
- `/status` - Check account status
- `/help` - Show help

### Admin Commands:

- `/reply <user_id> <message>` - Reply to user
- `/close_topic` - Close current topic
- `/reopen_topic` - Reopen closed topic
- `/admin_help` - Show admin help

## Group Structure

```
FlowGroove Support (Forum)
├─ 📢 Announcements (read-only)
├─ 💬 General Chat
├─ 🔧 Support: username1
├─ 🔧 Support: username2
├─ 🔧 Support: user123
└─ ...
```

## Topic Management

### Automatic:
- Topic created when user sends `/start`
- Topic linked to user's Telegram ID
- Welcome message sent in topic

### Manual (Admin):
```
/close_topic    # Close resolved topic
/reopen_topic   # Reopen if needed
```

## Firestore Collections

### support_topics
```javascript
{
  user_id: "7RPi5xPJV5XeTm0SIWubea9DVjJ3",
  topic_id: 12345,
  created_at: Timestamp
}
```

### users (updated)
```javascript
{
  telegramId: "123456789",
  telegramUsername: "username",
  telegramFirstName: "First",
  telegramLastName: "Last",
  telegramLinkedAt: Timestamp
}
```

## Project Structure

```
telegram_bot/
├── bot/
│   ├── __init__.py
│   ├── main.py              # Entry point
│   ├── config.py            # Configuration
│   ├── handlers/
│   │   ├── start.py         # /start + topic creation
│   │   ├── link.py          # /link
│   │   ├── help.py          # /help
│   │   ├── unlink.py        # /unlink
│   │   ├── status.py        # /status
│   │   ├── support.py       # Support messages
│   │   └── admin.py         # Admin commands
│   └── services/
│       ├── firestore.py     # Firebase integration
│       └── support_topics.py # Topic management
├── requirements.txt
├── .env
└── README.md
```

## Troubleshooting

### Bot doesn't create topics

1. Check bot is **admin** in group
2. Check **Forum** is enabled
3. Check `SUPPORT_GROUP_ID` is correct (starts with `-100`)

### Commands not working

1. Check bot token in `.env`
2. Check bot is running: `ps aux | grep python`
3. Check logs for errors

### Admin commands not working

1. Check your Telegram ID in `ADMIN_IDS`
2. Get your ID from @userinfobot
3. Restart bot after config change

## Deployment

### Railway.app (Recommended)

1. Create new project
2. Connect GitHub repo
3. Set environment variables
4. Deploy automatically

### Render.com

1. Create Web Service
2. Connect GitHub
3. Set env variables
4. Deploy

### VPS

```bash
# Install Python 3.10+
pip install -r requirements.txt

# Use systemd service
sudo systemctl edit --force repsync-bot

# [Unit]
# Description=FlowGroove Telegram Bot
# After=network.target

# [Service]
# Type=simple
# User=www-data
# WorkingDirectory=/path/to/telegram_bot
# ExecStart=/usr/bin/python3 bot/main.py
# Restart=always

# [Install]
# WantedBy=multi-user.target

sudo systemctl enable repsync-bot
sudo systemctl start repsync-bot
```

## License

MIT

## Support

Contact @flowgroove_support
