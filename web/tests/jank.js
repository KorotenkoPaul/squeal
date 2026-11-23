// Smoothness: records every animation frame while the main animations play (page up/down, chat push, part switch,
// a choice, tab switches, refresh, the reel) and fails on any frame longer than 50 ms; also sums layout shifts
// (Chromium's layout-shift entries) at launch and on tab switches — nothing should jump.
// Run: node web/tests/jank.js
const { chromium } = require('playwright');
const { pageUrl, PHONES, phone, watch, sleep } = require('./lib');
(async () => {
  const b = await chromium.launch(), fails = [], report = [];
  const ctx = await phone(b, PHONES.iphone16), p = await ctx.newPage(), errs = watch(p), url = pageUrl();
  await p.addInitScript(() => { window.__cls = 0; try { new PerformanceObserver(l => l.getEntries().forEach(e => { if (!e.hadRecentInput) window.__cls += e.value; })).observe({ type: 'layout-shift', buffered: true }); } catch {} });
  await p.goto(url); await p.evaluate(() => { localStorage.clear(); localStorage.setItem('squeal:premium', 'true'); localStorage.setItem('squeal:lang', '"en"'); localStorage.setItem('squeal:p:nobodys-home', JSON.stringify({ ep: 0, pos: [20, 10, 0] })); });
  await p.goto(url); await sleep(2000);
  const cdp = await ctx.newCDPSession(p); const T = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
  const drag = async (x0, y0, x1, y1, n = 20) => { await T('touchStart', [{ x: x0, y: y0 }]); for (let k = 1; k <= n; k++) { await T('touchMove', [{ x: x0 + (x1 - x0) * k / n, y: y0 + (y1 - y0) * k / n }]); await sleep(16); } await T('touchEnd', []); };
  const frames = async (name, act, ms = 1200) => {
    await p.evaluate(() => { window.__f = []; let last = performance.now(); const f = t => { window.__f.push(t - last); last = t; if (window.__on) requestAnimationFrame(f); }; window.__on = true; requestAnimationFrame(f); });
    await act(); await sleep(ms);
    const d = await p.evaluate(() => { window.__on = false; return window.__f.slice(1); });
    const max = Math.max(...d), long = d.filter(x => x > 50).length;
    report.push(`${name}: ${d.length} frames, longest ${max.toFixed(0)} ms`);
    if (long) fails.push(`${name}: ${long} frame(s) over 50 ms (longest ${max.toFixed(0)} ms)`);
  };
  const cls0 = await p.evaluate(() => window.__cls);
  if (cls0 > .01) fails.push(`launch: layout shift ${cls0.toFixed(3)}`);
  for (const t of ['fav', 'search', 'menu', 'home']) await frames('tab ' + t, () => p.click('#tab-' + t), 600);
  const cls1 = await p.evaluate(() => window.__cls);
  report.push(`layout shift: launch ${cls0.toFixed(3)}, after tab switches ${cls1.toFixed(3)}`);
  await frames('page up', () => p.evaluate(() => preview('nobodys-home')));
  await frames('page down (✕)', () => p.click('#pv-back'));
  await p.evaluate(() => preview('nobodys-home')); await sleep(900);
  await frames('chat push', () => p.click('#pv-read'), 1600);
  await frames('part switch', () => p.click('.ep-seg [data-ep="1"]'), 1600);
  await frames('chat back', () => p.click('#back'));
  await p.evaluate(() => { const s = STORIES.find(x => x.id === 'two-knocks'), e = s.episodes[0];
    localStorage.setItem('squeal:p:two-knocks', JSON.stringify({ ep: 0, pos: [e.nodes[e.start].messages.length], path: [e.start], v: s.v })); openStory('two-knocks', 0); }); await sleep(2600);
  await frames('a choice', () => p.click('.screen .draft'), 2600);
  await p.evaluate(() => document.querySelector('#back').click()); await sleep(900);
  await frames('refresh', () => drag(196, 260, 196, 520, 24), 1800);
  await p.evaluate(() => document.getElementById('view').scrollTo(0, 1e5)); await sleep(400);
  await frames('random reel', () => drag(196, 700, 196, 160, 30), 2200);
  await b.close();
  errs.forEach(e => fails.push(e));
  console.log(report.join('\n'));
  console.log(fails.length ? 'jank PROBLEMS\n  ' + fails.join('\n  ') : 'jank ok: no frame over 50 ms, no layout shift');
  process.exit(fails.length ? 1 : 0);
})();
