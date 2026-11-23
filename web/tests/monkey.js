// Monkey test: random touches anywhere for a few minutes (taps, swipes in all directions, holds, double taps); every
// 10 touches, after a pause, checks nothing is stuck or off place and no error was logged. Run: node web/tests/monkey.js
// (N=touches, SEED, W, H, LANGX=de|fr|es|ru). Exits 1 on problems.
// random touches anywhere (taps, swipes in all directions, holds, double taps), then after a pause check nothing is stuck
const { chromium } = require('playwright');
const { pageUrl, phone, watch } = require('./lib');
let rs = +(process.env.SEED || 1); const rnd = () => (rs = (rs * 1103515245 + 12345) % 2147483648) / 2147483648;
const W = +(process.env.W || 390), H = +(process.env.H || 844);
(async () => { const b = await chromium.launch(); const ctx = await phone(b, { width: W, height: H }); const pg = await ctx.newPage();
  const errs = watch(pg);
  await pg.goto(pageUrl({ fast: true })); await pg.waitForTimeout(1200);
  await pg.evaluate(l => { localStorage.setItem('squeal:premium', 'true'); if (l) { localStorage.setItem('squeal:lang', JSON.stringify(l)); } }, process.env.LANGX || ''); if (process.env.LANGX) { await pg.reload(); await pg.waitForTimeout(1200); }
  const cdp = await ctx.newCDPSession(pg); const T = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
  const bad = []; let log = [];
  const check = async i => { await pg.waitForTimeout(2200); const r = await pg.evaluate(() => { const o = [], A = { left: document.getElementById('app').offsetLeft };   // by layout: the app is drawn smaller while a story page is open
      if (document.documentElement.scrollWidth > innerWidth + 1) o.push('page wider than the screen');
      if (document.getElementById('app').style.transform && !document.querySelector('#layer .sheet')) o.push('home left sunk back');
      if (document.getElementById('app').classList.contains('boot')) o.push('app still hidden');
      if (typeof PULLING !== 'undefined' && PULLING) o.push('PULLING stuck');
      if (typeof HSWIPE !== 'undefined' && HSWIPE) o.push('HSWIPE stuck');
      const scr = [...document.querySelectorAll('#layer .screen')], sh = [...document.querySelectorAll('#layer .sheet')];
      if (scr.length > 1) o.push('two chats'); if (sh.length > 1) o.push('two previews');
      scr.forEach(s => { const q = s.getBoundingClientRect(); if (Math.abs(q.left - A.left) > 1 || Math.abs(q.top) > 1) o.push(`chat off place ${q.left|0},${q.top|0}`); if (s.style.pointerEvents === 'none') o.push('chat stuck leaving');
        s.querySelectorAll('.log:not(.log-ghost) > *').forEach(m => { if (m.style.visibility === 'hidden') o.push('hidden message'); if (m.style.translate && m.style.translate !== '0px') o.push('message offset ' + m.style.translate); });
        if (s.querySelector('.log-ghost')) o.push('old part left'); if (s.querySelector('.draft.on')) o.push('flying answer left'); });
      sh.forEach(s => { const q = s.getBoundingClientRect(); if (Math.abs(q.left - A.left) > 1 || Math.abs(q.top) > 1 || Math.abs(q.height - innerHeight) > 2) o.push(`preview off place ${q.left|0},${q.top|0},${q.height|0}`); if (s.style.visibility === 'hidden' && !scr.length) o.push('preview hidden with no chat'); });
      const v = document.getElementById('view'); if (v && v.style.transform && !/^(none|translateY\(0px\))?$/.test(v.style.transform)) o.push('home page offset ' + v.style.transform);
      document.querySelectorAll('.row-card').forEach(c => { if (c._x && Math.abs(c._x) > 1 && Math.abs(c._x) < 60) o.push('favourites row half open ' + c._x); });
      const run = document.getAnimations().filter(a => a.playState === 'running' && a.effect?.getTiming().iterations !== Infinity && !/^(roll|roll2|settle|rise)$/.test(a.animationName || '')); if (run.length > 3) o.push(`${run.length} animations still running: ${run.map(a => a.animationName || a.effect?.target?.className).slice(0, 4)}`);
      if (document.querySelectorAll('.toast').length > 1) o.push('toasts piled');
      return o; });
    r.forEach(x => bad.push(`${i}: ${x} | ${log.slice(-4).join(' > ')}`)); log = []; };
  for (let i = 0; i < +(process.env.N || 150); i++) {
    const a = rnd(), x = 5 + rnd() * (W - 10), y = 5 + rnd() * (H - 10);
    if (a < .45) { await T('touchStart', [{ x, y }]); await pg.waitForTimeout(rnd() * 120); await T('touchEnd', []); log.push(`tap ${x|0},${y|0}`); }
    else if (a < .55) { for (let k = 0; k < 2; k++) { await T('touchStart', [{ x, y }]); await T('touchEnd', []); await pg.waitForTimeout(40 + rnd() * 120); } log.push(`dbl ${x|0},${y|0}`); }
    else if (a < .85) { const ang = rnd() * Math.PI * 2, len = 30 + rnd() * 300, n = 4 + Math.floor(rnd() * 12), ms = rnd() * 30;
      await T('touchStart', [{ x, y }]); for (let k = 1; k <= n; k++) { await T('touchMove', [{ x: x + Math.cos(ang) * len * k / n, y: y + Math.sin(ang) * len * k / n }]); if (ms) await pg.waitForTimeout(ms); }
      if (rnd() < .3) await pg.waitForTimeout(rnd() * 600); await T(rnd() < .08 ? 'touchCancel' : 'touchEnd', []); log.push(`swipe ${x|0},${y|0} ${Math.round(ang * 57)}° ${len|0}`); }
    else { await T('touchStart', [{ x, y }]); await pg.waitForTimeout(300 + rnd() * 900); await T('touchEnd', []); log.push(`hold ${x|0},${y|0}`); }
    await pg.waitForTimeout(rnd() * 500);
    if (i % 10 === 9) await check(i);
  }
  console.log(`monkey seed ${process.env.SEED || 1} ${W}x${H}:`, bad.length + errs.length ? 'PROBLEMS' : 'clean'); [...errs, ...bad].slice(0, 10).forEach(x => console.log('  ' + x)); await b.close(); process.exit(bad.length + errs.length ? 1 : 0); })();
