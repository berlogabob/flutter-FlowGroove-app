"""
Support message handler
Forwards messages from users to support group topics
"""

from aiogram import F, Router
from aiogram.types import Message
from bot.config import Config

router = Router(name="support")


# Handle all text messages (not commands)
@router.message(~F.command)
async def handle_support_message(message: Message):
    """
    Handle support messages from users
    Forward to support group topic
    """

    user_id = str(message.from_user.id)
    username = message.from_user.username or message.from_user.first_name or "Unknown"

    # Get support group ID
    if not hasattr(message.bot, "config") or not message.bot.config.SUPPORT_GROUP_ID:
        await message.answer(
            "⚠️ *Support Not Configured*\n\nPlease contact @repsync_support directly.",
            parse_mode="Markdown",
        )
        return

    support_group_id = message.bot.config.SUPPORT_GROUP_ID

    # TODO: Get user's topic ID from Firestore
    # For now, send to general topic
    topic_id = None  # Will be retrieved from Firestore

    # Forward message to support group
    try:
        # Send to support group
        await message.bot.send_message(
            chat_id=support_group_id,
            message_thread_id=topic_id,  # None = general chat
            text=f"""📩 *New Support Message*

*From:* {username} (`{user_id}`)
*Message:* {message.text}""",
            parse_mode="Markdown",
        )

        # Confirm to user
        await message.answer(
            "✅ *Message Sent*\n\n"
            "Your message has been sent to support team.\n"
            "We'll respond as soon as possible.",
            parse_mode="Markdown",
        )

    except Exception as e:
        print(f"Error forwarding support message: {e}")
        await message.answer(
            "❌ *Error*\n\n"
            "Failed to send message to support. "
            "Please try again later or contact @repsync_support.",
            parse_mode="Markdown",
        )
