"""
RepSync Telegram Bot - Main Entry Point
Support Group + Topics Edition
"""

import asyncio
import logging

from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage
from bot.config import Config
from bot.handlers import register_handlers
from bot.services.firestore import init_firestore

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


async def main():
    """Main function"""

    # Validate config
    Config.validate()
    logger.info("Configuration loaded successfully")

    # Initialize Firebase
    db = init_firestore(Config.FIREBASE_CREDENTIALS)
    logger.info("Firebase initialized")

    # Initialize bot
    storage = MemoryStorage()
    bot = Bot(token=Config.TELEGRAM_BOT_TOKEN)
    dp = Dispatcher(storage=storage)

    # Store db in bot for access in handlers
    bot.db = db
    bot.config = Config

    # Register handlers
    register_handlers(dp, db, Config)
    logger.info("Handlers registered")

    # Log configuration
    logger.info(f"Support Group ID: {Config.SUPPORT_GROUP_ID}")
    logger.info(f"Admins configured: {len(Config.ADMIN_IDS)}")

    # Setup webhook or polling
    if Config.WEBHOOK_URL:
        # Webhook mode (for production)
        await bot.set_webhook(Config.WEBHOOK_URL)
        logger.info(f"Webhook set to {Config.WEBHOOK_URL}")
        logger.warning("Webhook mode requires a web server (e.g., aiohttp + gunicorn)")
    else:
        # Polling mode (for local testing)
        logger.info("Starting bot in polling mode...")
        logger.info("Press Ctrl+C to stop")
        await dp.start_polling(bot)

    logger.info("Bot stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.error(f"Bot error: {e}", exc_info=True)
