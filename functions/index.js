/**
 * Firebase Cloud Functions entry point.
 *
 * This file only wires module exports. Implementations live under `src/`:
 *   - src/telegram/  — Telegram bot (webhook + handlers + services)
 *   - src/canonical  — canonical song matching
 *   - src/bands      — band membership
 *   - src/avatars    — avatar import callable
 */

// Telegram bot webhook
const telegram = require("./src/telegram/webhook");
exports.telegramWebhook = telegram.telegramWebhook;

// Canonical song
const canonical = require("./src/canonical");
exports.ensureCanonicalSong = canonical.ensureCanonicalSong;

// Band membership
const bands = require("./src/bands");
exports.joinBand = bands.joinBand;
exports.updateBandMember = bands.updateBandMember;

// Avatars
const avatars = require("./src/avatars");
exports.importTelegramAvatar = avatars.importTelegramAvatar;
