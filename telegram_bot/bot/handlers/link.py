"""
/link command handler
"""
from aiogram import Router, F
from aiogram.types import Message
from bot.services.firestore import link_user_account

router = Router(name='link')

@router.message(F.command == 'link')
async def handle_link_command(message: Message):
    """Handle /link command"""
    
    # Get user ID from command args
    args = message.text.split()
    
    if len(args) < 2:
        usage_text = """❌ *Usage:* /link <your_user_id>

*How to get your user ID:*
1. Open RepSync app
2. Go to Profile
3. Your user ID is shown there

Or click the link button in the RepSync app!"""
        await message.answer(usage_text, parse_mode='Markdown')
        return
    
    user_id = args[1]
    
    # Strip 'link_' prefix if present
    if user_id.startswith('link_'):
        user_id = user_id[5:]
    
    # Call link function
    await link_user(message, user_id)

async def link_user(message: Message, user_id: str):
    """Link user account"""
    
    telegram_id = str(message.from_user.id)
    telegram_data = {
        'username': message.from_user.username,
        'first_name': message.from_user.first_name,
        'last_name': message.from_user.last_name,
        'photo': None,
    }
    
    # Get db from app context
    db = message.bot.db if hasattr(message.bot, 'db') else None
    
    if db is None:
        await message.answer(
            "❌ *Error*\n\nDatabase not configured. Please contact support.",
            parse_mode='Markdown'
        )
        return
    
    # Link account
    result = await link_user_account(db, telegram_id, user_id, telegram_data)
    
    if result['success']:
        success_text = """✅ *Account Linked Successfully!*

Your Telegram account is now connected to RepSync.

*What's next?*
• Your profile photo will be imported to RepSync
• You'll receive notifications about band activities
• Your Telegram name will be used in RepSync

Use /help to see all available commands."""
        await message.answer(success_text, parse_mode='Markdown')
    else:
        error_text = f"❌ *Error*\n\n{result['message']}"
        if result['error'] == 'already_linked':
            error_text += "\n\nUse /unlink first to disconnect."
        await message.answer(error_text, parse_mode='Markdown')
