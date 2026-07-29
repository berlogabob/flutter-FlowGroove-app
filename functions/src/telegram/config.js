/**
 * Telegram bot configuration: Firebase Admin handle, environment params, and
 * small shared helpers. Required by every telegram handler/service module.
 */
const admin = require("firebase-admin");
const { defineString } = require("firebase-functions/params");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const TELEGRAM_BOT_TOKEN = defineString("TELEGRAM_BOT_TOKEN");
// Optional params default to "" so deploy never prompts for them; the getters
// below already treat empty as "not configured".
const SUPPORT_GROUP_ID_PARAM = defineString("SUPPORT_GROUP_ID", { default: "" });
const ADMIN_IDS_PARAM = defineString("ADMIN_IDS", { default: "" });

function getSupportGroupId() {
  try {
    return SUPPORT_GROUP_ID_PARAM.value() || null;
  } catch (e) {
    return null;
  }
}

function getAdminIds() {
  try {
    const value = ADMIN_IDS_PARAM.value();
    if (!value) return [];
    return value.split(",").map((id) => parseInt(id.trim()));
  } catch (e) {
    return [];
  }
}

function isAdmin(userId) {
  return getAdminIds().includes(userId);
}

/** Strips the "link_" deep-link prefix from a /start payload user id. */
function cleanUserId(userId) {
  return userId.startsWith("link_") ? userId.substring(5) : userId;
}

module.exports = {
  admin,
  db,
  TELEGRAM_BOT_TOKEN,
  getSupportGroupId,
  getAdminIds,
  isAdmin,
  cleanUserId,
};
