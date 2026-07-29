/**
 * Per-user support forum topics.
 *
 * Maps each Telegram user to a forum topic (message thread) in the support
 * group so their support conversation is isolated. Mappings live in Firestore
 * `support_topics/{telegramId}` with a `threadId` field.
 *
 * Degrades gracefully: if the support group is not a forum, `createForumTopic`
 * fails and `getOrCreateUserTopic` returns null so callers fall back to flat
 * forwarding.
 */
const { db, admin } = require("../config");

const COLLECTION = "support_topics";
const ICON_COLOR = 0x6fb9f0; // blue

/** Returns the stored thread id for a user, or null. */
async function getUserTopic(telegramId) {
  const doc = await db.collection(COLLECTION).doc(String(telegramId)).get();
  return doc.exists ? doc.data().threadId : null;
}

/** Reverse lookup: returns the telegramId mapped to a thread id, or null. */
async function getUserByTopic(threadId) {
  const snap = await db
    .collection(COLLECTION)
    .where("threadId", "==", threadId)
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0].id;
}

/**
 * Returns an existing topic thread id for the user, creating one if needed.
 * Returns null if the group has no forum topics (caller should fall back to
 * flat forwarding).
 *
 * @param {object} telegram - Telegraf `ctx.telegram` (or a compatible client)
 */
async function getOrCreateUserTopic(telegram, groupId, telegramId, username) {
  const existing = await getUserTopic(telegramId);
  if (existing) return existing;

  let topic;
  try {
    topic = await telegram.createForumTopic(groupId, `🔧 ${username || telegramId}`, {
      icon_color: ICON_COLOR,
    });
  } catch (e) {
    console.error(
      "createForumTopic failed (support group may not be a forum):",
      e.message,
    );
    return null;
  }

  const threadId = topic.message_thread_id;
  await db.collection(COLLECTION).doc(String(telegramId)).set({
    threadId,
    username: username || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return threadId;
}

module.exports = { getUserTopic, getUserByTopic, getOrCreateUserTopic, COLLECTION };
