"""
Admin handlers for support group
Allows admins to respond to support tickets
"""

from aiogram import F, Router
from aiogram.filters import Command
from aiogram.types import CallbackQuery, Message
from bot.config import Config

router = Router(name="admin")


# Filter for admin messages
def is_admin(user_id: int) -> bool:
    return user_id in Config.ADMIN_IDS


@router.message(Command("reply"))
async def handle_reply_command(message: Message):
    """
    Admin command to reply to support ticket
    Usage: /reply <user_id> <message>
    """

    if not is_admin(message.from_user.id):
        return

    # Parse command
    args = message.text.split(maxsplit=2)

    if len(args) < 3:
        await message.answer(
            "❌ *Usage:* `/reply <user_id> <message>`\n\n"
            "Example: `/reply 123456789 Hello! How can I help?`",
            parse_mode="Markdown",
        )
        return

    user_id = args[1]
    reply_text = args[2]

    # TODO: Get user's topic ID from Firestore
    # For now, send to user directly in DM
    try:
        await message.bot.send_message(
            chat_id=user_id,
            text=f"""📬 *Support Response*

{reply_text}

---
*RepSync Support Team*""",
            parse_mode="Markdown",
        )

        # Confirm to admin
        await message.answer(
            f"✅ *Message Sent*\n\nReply sent to user `{user_id}`",
            parse_mode="Markdown",
        )

    except Exception as e:
        await message.answer(
            f"❌ *Error*\n\nFailed to send message: {e}", parse_mode="Markdown"
        )


@router.message(Command("close_topic"))
async def handle_close_topic(message: Message):
    """
    Admin command to close support topic
    Usage: /close_topic
    """

    if not is_admin(message.from_user.id):
        return

    # Check if in forum topic
    if not message.message_thread_id:
        await message.answer(
            "❌ *Error*\n\nThis command must be used in a forum topic.",
            parse_mode="Markdown",
        )
        return

    # Close the topic
    try:
        await message.bot.close_forum_topic(
            chat_id=Config.SUPPORT_GROUP_ID,
            message_thread_id=message.message_thread_id,
        )

        await message.answer(
            "✅ *Topic Closed*\n\nThis support topic has been closed.",
            parse_mode="Markdown",
        )

    except Exception as e:
        await message.answer(
            f"❌ *Error*\n\nFailed to close topic: {e}", parse_mode="Markdown"
        )


@router.message(Command("reopen_topic"))
async def handle_reopen_topic(message: Message):
    """
    Admin command to reopen closed topic
    Usage: /reopen_topic
    """

    if not is_admin(message.from_user.id):
        return

    # Check if in forum topic
    if not message.message_thread_id:
        await message.answer(
            "❌ *Error*\n\nThis command must be used in a forum topic.",
            parse_mode="Markdown",
        )
        return

    # Reopen the topic
    try:
        await message.bot.reopen_forum_topic(
            chat_id=Config.SUPPORT_GROUP_ID,
            message_thread_id=message.message_thread_id,
        )

        await message.answer(
            "✅ *Topic Reopened*\n\nThis support topic has been reopened.",
            parse_mode="Markdown",
        )

    except Exception as e:
        await message.answer(
            f"❌ *Error*\n\nFailed to reopen topic: {e}", parse_mode="Markdown"
        )


@router.message(Command("admin_help"))
async def handle_admin_help(message: Message):
    """
    Show admin commands help
    """

    if not is_admin(message.from_user.id):
        return

    help_text = """📖 *Admin Commands*

/reply <user_id> <message> - Reply to user
/close_topic - Close current topic
/reopen_topic - Reopen closed topic
/admin_help - Show this help

*Support Group Setup:*
1. Create supergroup with Forum enabled
2. Add bot as admin
3. Set SUPPORT_GROUP_ID in .env
4. Set ADMIN_IDS in .env"""

    await message.answer(help_text, parse_mode="Markdown")
