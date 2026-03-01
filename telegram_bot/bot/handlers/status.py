"""
/status command handler
"""
from aiogram import Router, F
from aiogram.types import Message
from bot.services.firestore import get_user_status

router = Router(name='status')

@router.message(F.command == 'status')
async def handle_status(message: Message):
    """Handle /status command"""
    
    telegram_id = str(message.from_user.id)
    
    # Get db from app context
    db = message.bot.db if hasattr(message.bot, 'db') else None
    
    if db is None:
        await message.answer(
            "❌ *Error*\n\nDatabase not configured. Please contact support.",
            parse_mode='Markdown'
        )
        return
    
    # Get status
    status = await get_user_status(db, telegram_id)
    
    if status['linked']:
        status_text = f"""✅ *Account Status*

*RepSync User ID:* `{status['user_id']}`
*Display Name:* {status['display_name']}
*Email:* {status['email']}
*Linked:* Yes

Use /unlink to disconnect your account."""
        await message.answer(status_text, parse_mode='Markdown')
    else:
        not_linked_text = """❌ *Not Linked*

Your Telegram account is not linked to any RepSync account.

Use /link <your_user_id> to link your account."""
        await message.answer(not_linked_text, parse_mode='Markdown')
