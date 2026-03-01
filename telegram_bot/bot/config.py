"""
RepSync Telegram Bot Configuration
"""

import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    """Bot configuration"""

    # Telegram Bot Token
    TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")

    # Firebase
    FIREBASE_CREDENTIALS = os.getenv("FIREBASE_CREDENTIALS", "serviceAccountKey.json")

    # Support Group
    SUPPORT_GROUP_ID = os.getenv("SUPPORT_GROUP_ID")
    GENERAL_TOPIC_ID = int(os.getenv("GENERAL_TOPIC_ID", "1"))
    ANNOUNCEMENTS_TOPIC_ID = int(os.getenv("ANNOUNCEMENTS_TOPIC_ID", "2"))

    # Admins
    ADMIN_IDS = [
        int(x.strip()) for x in os.getenv("ADMIN_IDS", "").split(",") if x.strip()
    ]

    # Bot Info
    BOT_NAME = "RepSync Bot"
    SUPPORT_USERNAME = "@repsync_support"

    # Webhook
    WEBHOOK_URL = os.getenv("WEBHOOK_URL", "")

    @classmethod
    def validate(cls):
        """Validate configuration"""
        if not cls.TELEGRAM_BOT_TOKEN:
            raise ValueError("TELEGRAM_BOT_TOKEN not set in .env")
        if not cls.SUPPORT_GROUP_ID:
            raise ValueError("SUPPORT_GROUP_ID not set in .env")
        if not cls.ADMIN_IDS:
            print("⚠️  Warning: ADMIN_IDS not set. No admins configured.")
        return True
