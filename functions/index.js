/**
 * Firebase Cloud Functions entry point.
 *
 * This file only wires module exports. Implementations live under `src/`:
 *   - src/telegram/  — Telegram bot (webhook + handlers + services)
 *   - src/canonical  — canonical song matching
 *   - src/bands      — band membership
 *   - src/avatars    — avatar import callable
 *   - src/rehearsals — rehearsal plan notifications + actions
 */

// Telegram bot webhook
const telegram = require("./src/telegram/webhook");
exports.telegramWebhook = telegram.telegramWebhook;

// Canonical song
const canonical = require("./src/canonical");
exports.ensureCanonicalSong = canonical.ensureCanonicalSong;
exports.updateCanonicalSong = canonical.updateCanonicalSong;

// Band membership
const bands = require("./src/bands");
exports.joinBand = bands.joinBand;
exports.updateBandMember = bands.updateBandMember;
exports.getBandInviteInfo = bands.getBandInviteInfo;

// Account deletion (server-authoritative; Google Play data-deletion requirement)
const account = require("./src/account");
exports.deleteAccount = account.deleteAccount;

// MCP endpoint: per-user API keys (callables) + the authenticated HTTP gateway.
const mcpKeys = require("./src/mcp/keys");
exports.createApiKey = mcpKeys.createApiKey;
exports.listApiKeys = mcpKeys.listApiKeys;
exports.revokeApiKey = mcpKeys.revokeApiKey;
const mcpGateway = require("./src/mcp/gateway");
exports.mcpGateway = mcpGateway.mcpGateway;
const mcpRemote = require("./src/mcp/remote");
exports.mcpRemote = mcpRemote.mcpRemote;

// Band avatar (server-authoritative; admin verified server-side)
const bandAvatar = require("./src/band_avatar");
exports.setBandAvatar = bandAvatar.setBandAvatar;
exports.removeBandAvatar = bandAvatar.removeBandAvatar;

// Avatars
const avatars = require("./src/avatars");
exports.importTelegramAvatar = avatars.importTelegramAvatar;
exports.importGoogleAvatar = avatars.importGoogleAvatar;

// CORS shim for public no-auth APIs (Deezer, lyrics.ovh) — web autofill only
const apiProxy = require("./src/api_proxy");
exports.apiProxy = apiProxy.apiProxy;

// Telegram sharing + notifications
const telegramShare = require("./src/telegram/share");
exports.shareToTelegram = telegramShare.shareToTelegram;

const telegramReminders = require("./src/telegram/reminders");
exports.onBandSetlistCreated = telegramReminders.onBandSetlistCreated;
exports.dailyEventReminder = telegramReminders.dailyEventReminder;

// Rehearsal plan notifications + actions
const rehearsals = require("./src/rehearsals");
exports.onRehearsalCreated = rehearsals.onRehearsalCreated;
exports.onRehearsalConfirmed = rehearsals.onRehearsalConfirmed;
exports.remindRehearsalVoters = rehearsals.remindRehearsalVoters;
