// Shared helpers for the browser tests in web/tests (Playwright + Chromium, no network needed but fonts).
// The built page has no viewport tag of its own (the artifact host adds one), so the tests serve a copy with the
// same tag an iPhone gets, from a temp folder that links the covers, voices and videos next to it.
const fs = require('fs'), os = require('os'), path = require('path');
const WEB = path.resolve(__dirname, '..');
const VIEWPORT = '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">';

/* fast: typing pauses shortened to 350 ms (walks through whole stories in reasonable time) */
function pageUrl({ fast = false } = {}) {
  const dir = path.join(os.tmpdir(), 'squeal-test-' + (fast ? 'fast' : 'real'));
  fs.mkdirSync(dir, { recursive: true });
  for (const d of ['covers', 'brand', 'voice', 'video']) {
    const l = path.join(dir, d); try { fs.unlinkSync(l); } catch {} fs.symlinkSync(path.join(WEB, d), l);
  }
  let src = fs.readFileSync(path.join(WEB, 'squeal-preview.html'), 'utf8');
  src = src.replace('<meta charset="utf-8">', '<meta charset="utf-8">' + VIEWPORT);
  if (fast) { const old = 'Math.min(1800, 450 + m.text.length * 22)'; if (!src.includes(old)) throw new Error('typing delay not found'); src = src.replace(old, '350'); }
  fs.writeFileSync(path.join(dir, 'index.html'), src);
  return 'file://' + path.join(dir, 'index.html');
}
const PHONES = { iphone16: { width: 393, height: 852 }, iphoneSE: { width: 375, height: 667 } };
function phone(browser, size = PHONES.iphone16, extra = {}) {
  return browser.newContext({ viewport: size, hasTouch: true, isMobile: true, deviceScaleFactor: 2, ...extra });
}
/* collects page errors and console errors */
function watch(page) { const errs = []; page.on('pageerror', e => errs.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' && !/fonts\.(googleapis|gstatic)|net::ERR/.test(m.text())) errs.push('console: ' + m.text()); }); return errs; }
const sleep = ms => new Promise(r => setTimeout(r, ms));
module.exports = { pageUrl, PHONES, phone, watch, sleep, WEB };
