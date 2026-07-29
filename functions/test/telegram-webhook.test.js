const assert = require("node:assert/strict");

const projectId = "repsync-app-callable-test";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || projectId;
process.env.FIREBASE_CONFIG =
  process.env.FIREBASE_CONFIG || JSON.stringify({ projectId });

const { makeTelegramWebhook } = require("../src/telegram/webhook");

function buildRes() {
  return {
    statusCode: null,
    payload: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(body) {
      this.payload = body;
      return this;
    },
  };
}

function buildReq({ method = "POST", secretHeader } = {}) {
  return {
    method,
    body: { update_id: 1 },
    get(name) {
      if (name === "X-Telegram-Bot-Api-Secret-Token") return secretHeader;
      return undefined;
    },
  };
}

function fakeBot() {
  const bot = {
    handled: false,
    handleUpdate: async () => {
      bot.handled = true;
    },
  };
  return bot;
}

describe("telegramWebhook secret verification", function () {
  this.timeout(10000);

  it("GET returns the health-check string", async () => {
    const fn = makeTelegramWebhook({
      getSecret: () => null,
      getBot: fakeBot,
    });
    const res = buildRes();
    await fn(buildReq({ method: "GET" }), res);
    assert.equal(res.statusCode, 200);
    assert.match(res.payload, /FlowGroove Bot/);
  });

  it("passes a POST through when no secret is configured (no-op)", async () => {
    const bot = fakeBot();
    const fn = makeTelegramWebhook({ getSecret: () => null, getBot: () => bot });
    await fn(buildReq({}), buildRes());
    assert.equal(bot.handled, true);
  });

  it("handles a POST when the secret matches the header", async () => {
    const bot = fakeBot();
    const fn = makeTelegramWebhook({
      getSecret: () => "s3cret",
      getBot: () => bot,
    });
    await fn(buildReq({ secretHeader: "s3cret" }), buildRes());
    assert.equal(bot.handled, true);
  });

  it("rejects a POST with a missing or wrong secret header (401)", async () => {
    const bot = fakeBot();
    const fn = makeTelegramWebhook({
      getSecret: () => "s3cret",
      getBot: () => bot,
    });

    const resMissing = buildRes();
    await fn(buildReq({}), resMissing);
    assert.equal(resMissing.statusCode, 401);

    const resWrong = buildRes();
    await fn(buildReq({ secretHeader: "nope" }), resWrong);
    assert.equal(resWrong.statusCode, 401);

    assert.equal(bot.handled, false, "bot must not process unauthorized updates");
  });

  it("rejects non-GET/POST methods with 405", async () => {
    const bot = fakeBot();
    const fn = makeTelegramWebhook({ getSecret: () => null, getBot: () => bot });
    const res = buildRes();
    await fn(buildReq({ method: "DELETE" }), res);
    assert.equal(res.statusCode, 405);
    assert.equal(bot.handled, false);
  });
});
