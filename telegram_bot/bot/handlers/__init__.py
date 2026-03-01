"""
Register all bot handlers
"""

from aiogram import Dispatcher
from bot.handlers.admin import router as admin_router
from bot.handlers.help import router as help_router
from bot.handlers.link import router as link_router
from bot.handlers.start import router as start_router
from bot.handlers.status import router as status_router
from bot.handlers.support import router as support_router
from bot.handlers.unlink import router as unlink_router


def register_handlers(dp: Dispatcher, db, config):
    """Register all handlers with dispatcher"""

    # User commands
    dp.include_router(start_router)
    dp.include_router(link_router)
    dp.include_router(help_router)
    dp.include_router(unlink_router)
    dp.include_router(status_router)

    # Support messages
    dp.include_router(support_router)

    # Admin commands (only if admins configured)
    if config.ADMIN_IDS:
        dp.include_router(admin_router)
