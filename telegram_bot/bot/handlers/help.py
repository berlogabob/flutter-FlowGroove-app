"""
/help command handler
"""
from aiogram import Router, F
from aiogram.types import Message
from bot.config import Config

router = Router(name='help')

@router.message(F.command == 'help')
async def handle_help(message: Message):
    """Handle /help command"""
    
    help_text = f"""📖 *RepSync Bot Commands:*

/start - Start using the bot
/link <user_id> - Link your RepSync account
/unlink - Unlink your Telegram account
/status - Check your account status
/help - Show this help message

*What can I do?*
• Link your Telegram to RepSync profile
• Send you notifications about band activities
• Import your Telegram name and photo to RepSync

*Need support?*
Contact {Config.SUPPORT_USERNAME}"""
    
    await message.answer(help_text, parse_mode='Markdown')
