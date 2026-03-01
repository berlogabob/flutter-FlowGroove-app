"""
Support Group & Topics Service
Manages Telegram group topics for user support
"""

from typing import Dict, Optional

from aiogram import Bot
from aiogram.exceptions import TelegramBadRequest


class SupportTopicService:
    """Service for managing support topics"""

    def __init__(self, bot: Bot, group_id: int):
        self.bot = bot
        self.group_id = group_id

    async def create_topic_for_user(self, user_id: str, username: str) -> Optional[int]:
        """
        Create a new support topic for user

        Returns:
            topic_id if created, None if failed
        """
        try:
            topic_name = f"🔧 Support: {username or user_id}"

            # Create forum topic
            topic = await self.bot.create_forum_topic(
                chat_id=self.group_id,
                name=topic_name,
                icon_color=0x6FB9F0,  # Blue color for support
            )

            # Store topic mapping in Firestore
            await self._save_topic_mapping(user_id, topic.message_thread_id)

            # Send welcome message in topic
            await self.bot.send_message(
                chat_id=self.group_id,
                message_thread_id=topic.message_thread_id,
                text=f"""👋 Welcome to RepSync Support!

Your personal support topic has been created.

*How it works:*
• Ask your question here
• Our team will respond soon
• This topic is private to you and support team

*Your User ID:* `{user_id}`""",
                parse_mode="Markdown",
            )

            return topic.message_thread_id

        except TelegramBadRequest as e:
            print(f"Error creating topic: {e}")
            return None
        except Exception as e:
            print(f"Unexpected error creating topic: {e}")
            return None

    async def get_user_topic(self, user_id: str) -> Optional[int]:
        """Get existing topic ID for user"""
        # This would query Firestore for topic mapping
        # For now, returns None (will create new topic)
        return None

    async def _save_topic_mapping(self, user_id: str, topic_id: int):
        """Save user_id to topic_id mapping in Firestore"""
        if not hasattr(self.bot, "db") or self.bot.db is None:
            print("Firestore not available, skipping topic mapping save")
            return

        try:
            await (
                self.bot.db.collection("support_topics")
                .document(user_id)
                .set(
                    {
                        "topic_id": topic_id,
                        "created_at": __import__("datetime").datetime.utcnow(),
                    }
                )
            )
        except Exception as e:
            print(f"Error saving topic mapping: {e}")

    async def close_topic(self, topic_id: int):
        """Close support topic"""
        try:
            await self.bot.close_forum_topic(
                chat_id=self.group_id,
                message_thread_id=topic_id,
            )
        except Exception as e:
            print(f"Error closing topic: {e}")

    async def reopen_topic(self, topic_id: int):
        """Reopen closed topic"""
        try:
            await self.bot.reopen_forum_topic(
                chat_id=self.group_id,
                message_thread_id=topic_id,
            )
        except Exception as e:
            print(f"Error reopening topic: {e}")
