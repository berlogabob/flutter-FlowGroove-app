// Browser-free checks for the pre-paint script and shared theme/menu behavior.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const theme = path.join(__dirname, '../themes/flowgroove');
const head = fs.readFileSync(path.join(theme, 'layouts/partials/theme-head.html'), 'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
const script = fs.readFileSync(path.join(theme, 'assets/js/fg.js'), 'utf8');
function element() {
  const listeners = {}, attrs = {}, classes = new Set();
  return {
    listeners, attrs, textContent: '',
    classList: { toggle(name, on) { on ? classes.add(name) : classes.delete(name); }, contains: name => classes.has(name) },
    addEventListener(name, callback) { listeners[name] = callback; },
    setAttribute(name, value) { attrs[name] = value; },
    getAttribute(name) { return attrs[name]; },
    focus() { this.focused = true; },
  };
}
for (const [saved, blocked] of [[null, false], ['dark', false], ['invalid', false], ['dark', true]]) {
  const root = { dataset: {} }, meta = {}, button = element(), label = {}, toggle = element();
  const nav = element(), header = element(), link = element(), details = {}, events = {};
  button.querySelector = () => label;
  nav.querySelectorAll = () => [link];
  const storage = {};
  const document = {
    documentElement: root,
    querySelector(selector) { return { 'meta[name="theme-color"]': meta, '.mobile-toggle': toggle, '.nav': nav, '.topbar': header }[selector]; },
    querySelectorAll(selector) { return { '.theme-toggle': [button], '.wiki-nav details': [details], '[data-ev]': [], '.faq-question': [] }[selector]; },
    addEventListener(name, callback) { events[name] = callback; },
  };
  const context = vm.createContext({ document, localStorage: {
    getItem(key) { assert.equal(key, 'fg-theme'); if (blocked) throw Error('blocked'); return saved; },
    setItem(key, value) { if (blocked) throw Error('blocked'); storage[key] = value; },
  }, window: { scrollY: 20, matchMedia: () => ({ matches: true, addEventListener() {} }), addEventListener(name, callback) { events[name] = callback; } } });
  vm.runInContext(head, context);
  const initial = saved === 'dark' && !blocked ? 'dark' : 'light';
  assert.equal(root.dataset.theme, initial);
  assert.equal(meta.content, initial === 'dark' ? '#0b0b0c' : '#f6f5f0');
  vm.runInContext(script, context);
  assert.equal(label.textContent, initial === 'dark' ? 'Dark' : 'Light');
  assert.equal(button.attrs['aria-pressed'], String(initial === 'dark'));
  assert.equal(details.open, false, 'Mobile wiki navigation starts collapsed');
  button.listeners.click();
  const next = initial === 'dark' ? 'light' : 'dark';
  assert.equal(root.dataset.theme, next);
  assert.equal(meta.content, next === 'dark' ? '#0b0b0c' : '#f6f5f0');
  assert.equal(button.attrs['aria-pressed'], String(next === 'dark'));
  if (!blocked) assert.equal(storage['fg-theme'], next);
  toggle.listeners.click();
  assert.equal(toggle.attrs['aria-expanded'], 'true');
  assert.equal(toggle.attrs['aria-label'], 'Close navigation');
  assert(nav.classList.contains('open'));
  events.keydown({ key: 'Escape' });
  assert.equal(toggle.attrs['aria-expanded'], 'false');
  assert(toggle.focused);
  toggle.listeners.click(); link.listeners.click();
  assert.equal(toggle.attrs['aria-label'], 'Open navigation');
  events.storage({ key: 'fg-theme', newValue: 'dark' });
  assert.equal(root.dataset.theme, 'dark');
  assert.equal(label.textContent, 'Dark');
}
console.log('PASS: pre-paint light default, persisted dark, denied storage, toggle/meta/ARIA, mobile menu/Escape, wiki collapse and tab sync.');
