// Browser check of the web launchpad (no login, no backend).
//   flutter build web --release -t lib/dev/web_launchpad_harness.dart --output build/web_harness
//   (cd build/web_harness && python3 -m http.server 8098 &)
//   npm i playwright-core && node scripts/web_launchpad_e2e.js   # needs a Chromium (PLAYWRIGHT chromium path in `exe`)
// Asserts every backing AudioBufferSource.start(when) coincides with a click
// oscillator tick on the same AudioContext clock (<5 ms; exact in practice).
const { chromium } = require('playwright-core');
const exe = process.env.HOME + '/Library/Caches/ms-playwright/chromium-1243/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing';
const click = (page, re) => page.evaluate((src) => {
  const re = new RegExp(src, 'i');
  const els = [...document.querySelectorAll('flt-semantics')].filter(e => re.test((e.getAttribute('aria-label') || '') + ' ' + (e.textContent || '')));
  els.sort((a, b) => (a.getBoundingClientRect().width * a.getBoundingClientRect().height) - (b.getBoundingClientRect().width * b.getBoundingClientRect().height));
  const e = els[0]; if (!e) return false;
  const r = e.getBoundingClientRect(); const x = r.x + r.width / 2, y = r.y + r.height / 2;
  for (const t of ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click']) e.dispatchEvent(new (t.startsWith('pointer') ? PointerEvent : MouseEvent)(t, { bubbles: true, clientX: x, clientY: y, pointerId: 1 }));
  return true;
}, re.source);
(async () => {
  const browser = await chromium.launch({ executablePath: exe, headless: true, args: ['--autoplay-policy=no-user-gesture-required','--use-gl=swiftshader','--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 420, height: 900 } });
  const errs = [];
  page.on('console', m => { if (m.type() === 'error') errs.push(m.text().slice(0, 240)); });
  page.on('pageerror', e => errs.push('PAGEERROR ' + String(e).slice(0, 300)));
  await page.addInitScript(() => {
    window.__log = { sources: [], osc: [], ctx: 0 };
    const AC = window.AudioContext;
    const cbs = AC.prototype.createBufferSource;
    AC.prototype.createBufferSource = function () {
      const s = cbs.call(this); const st = s.start.bind(s);
      s.start = (when, off, dur) => { window.__log.sources.push({ when, off, dur, now: this.currentTime, len: s.buffer ? s.buffer.length : 0 }); return st(when, off, dur); };
      return s;
    };
    const co = AC.prototype.createOscillator;
    AC.prototype.createOscillator = function () {
      const o = co.call(this); const st = o.start.bind(o);
      o.start = (when) => { window.__log.osc.push({ when, now: this.currentTime }); return st(when); };
      return o;
    };
    const orig = window.AudioContext;
    window.AudioContext = function (...a) { window.__log.ctx++; return new orig(...a); };
    window.AudioContext.prototype = orig.prototype;
  });
  await page.goto('http://localhost:8098/', { waitUntil: 'load' });
  await page.waitForTimeout(9000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);
  const labels = await page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map(e => (e.getAttribute('aria-label') || '').slice(0, 30)).filter(Boolean));
  console.log('labels:', JSON.stringify(labels.slice(0, 20)));
  console.log('play', await click(page, /^\s*play\s*$/));
  await page.waitForTimeout(2000);
  console.log('verse pad', await click(page, /verse/));
  await page.waitForTimeout(14000);
  const log = await page.evaluate(() => window.__log);
  console.log('contexts', log.ctx, 'bufferSources', log.sources.length, 'oscillators', log.osc.length);
  // every backing source start must coincide with a click tick on the same clock
  const osc = log.osc.map(o => o.when).sort((a, b) => a - b);
  let worst = 0, matched = 0;
  for (const s of log.sources) {
    const near = osc.reduce((b, w) => Math.abs(w - s.when) < Math.abs(b - s.when) ? w : b, osc[0]);
    const d = Math.abs(near - s.when) * 1000;
    if (d < 5) { matched++; worst = Math.max(worst, d); }
  }
  console.log('sources matched to a click tick within 5 ms:', matched, '/', log.sources.length, 'worst ms', worst.toFixed(4));
  console.log('first sources', JSON.stringify(log.sources.slice(0, 4)));
  console.log('errors:', JSON.stringify(errs, null, 1));
  await browser.close();
  if (errs.length || matched !== log.sources.length || !log.sources.length) process.exit(1);
})();
