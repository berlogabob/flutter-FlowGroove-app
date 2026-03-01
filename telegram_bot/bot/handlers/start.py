"""
/start command handler
Creates support topic for user
"""

from aiogram import F, Router
from aiogram.types import Message
from bot.services.support_topics import SupportTopicService

router = Router(name="start")


@router.message(F.command == "start")
async def handle_start(message: Message):
    """Handle /start command"""

    # Get user ID from deep link (if present)
    args = message.text.split()
    link_user_id = args[1] if len(args) > 1 else None

    # User info
    user_id = str(message.from_user.id)
    username = message.from_user.username or message.from_user.first_name

    # Welcome message
    welcome_text = f"""👋 *Welcome to RepSync!*

Hello {username}! I'm the RepSync bot.

*What I can do:*
• Link your Telegram account to RepSync app
• Create personal support topic
• Send you notifications about band activities
• Import your profile photo automatically

*Quick Start:*
1. Link account: `/link <your_user_id>`
2. Get support: Just ask in this chat
3. Learn more: `/help`

Need help? Use /help"""

    await message.answer(welcome_text, parse_mode="Markdown")

    # Create support topic
    if hasattr(message.bot, "config"):
        topic_service = SupportTopicService(
            message.bot, message.bot.config.SUPPORT_GROUP_ID
        )

        # Check if user already has a topic
        existing_topic = await topic_service.get_user_topic(user_id)

        if existing_topic:
            await message.answer(
                f"ℹ️ You already have a support topic.\n\n"
                f"You can continue asking questions there.",
                parse_mode="Markdown",
            )
        else:
            # Create new topic
            topic_id = await topic_service.create_topic_for_user(user_id, username)

            if topic_id:
                await message.answer(
                    f"✅ *Support Topic Created!*\n\n"
                    f"A personal support topic has been created for you in our support group.\n\n"
                    f"You'll be notified when support team responds.",
                    parse_mode="Markdown",
                )
            else:
                await message.answer(
                    "⚠️ *Note*\n\n"
                    "Could not create support topic right now. "
                    "Please contact support directly.",
                    parse_mode="Markdown",
                )

    # Auto-link if user ID provided
    if link_user_id:
        # Strip 'link_' prefix if present
        clean_user_id = (
            link_user_id[5:] if link_user_id.startswith("link_") else link_user_id
        )

        await message.answer(
            f"🔗 *Linking Account*\n\n"
            f"Attempting to link your Telegram account to RepSync...\n\n"
            f"User ID: `{clean_user_id}`",
            parse_mode="Markdown",
        )

        # Import link handler
        from bot.handlers.link import link_user

        await link_user(message, clean_user_id)
