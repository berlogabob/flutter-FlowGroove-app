/**
 * HTTPS entry point for the Telegram bot webhook. Telegram POSTs updates here;
 * GET returns a health-check string.
 */
const functions = require("firebase-functions");
const { bot } = require("./bot");

exports.telegramWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method === "POST") {
    await bot.handleUpdate(req.body, res);
  } else if (req.method === "GET") {
    res.status(200).send("FlowGroove Bot 🤖");
  } else {
    res.status(405).send("Method Not Allowed");
  }
});
