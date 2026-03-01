"""
/unlink command handler
"""
from aiogram import Router, F
from aiogram.types import Message
from bot.services.firestore import unlink_user_account

router = Router(name='unlink')

@router.message(F.command == 'unlink')
async def handle_unlink(message: Message):
    """Handle /unlink command"""
    
    telegram_id = str(message.from_user.id)
    
    # Get db from app context
    db = message.bot.db if hasattr(message.bot, 'db') else None
    
    if db is None:
        await message.answer(
            "❌ *Error*\n\nDatabase not configured. Please contact support.",
            parse_mode='Markdown'
        )
        return
    
    # Unlink account
    result = await unlink_user_account(db, telegram_id)
    
    if result['success']:
        await message.answer(
            "✅ Your Telegram account has been unlinked from RepSync.",
            parse_mode='Markdown'
        )
    else:
        error_text = f"❌ *Error*\n\n{result['message']}"
        await message.answer(error_text, parse_mode='Markdown')
