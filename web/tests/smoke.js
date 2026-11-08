// Smoke test for web/squeal-preview.html: opens every story's page and chat, with no progress, part-way
// and finished (old and new save formats), and fails on any page error. Run: node web/tests/smoke.js
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const url = 'file://' + path.resolve(__dirname, '..', 'squeal-preview.html');
  const b = await chromium.launch(); const fails = [];
  const p = await b.newPage({ viewport: { width: 390, height: 844 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto(url); await p.waitForTimeout(300);
  const stories = await p.evaluate(() => STORIES.map(s => ({ id: s.id, n: s.episodes.map(e => e.messages.length) })));
  for (const s of stories) {
    const saves = [null, JSON.stringify({ ep: 0, i: 3 }), JSON.stringify({ ep: s.n.length, i: 0 }),
      JSON.stringify({ ep: s.n.length - 1, pos: s.n.map((m, k) => k < s.n.length - 1 ? m : Math.floor(m / 2)) }), JSON.stringify({ ep: 0, pos: s.n })];
    for (const save of saves) {
      errs.length = 0;
      await p.evaluate(([id, sv]) => { localStorage.clear(); if (sv) localStorage.setItem('squeal:p:' + id, sv); document.querySelector('.screen')?.remove(); document.querySelector('.sheet')?.remove(); render(); }, [s.id, save]);
      await p.evaluate(id => preview(id), s.id); await p.waitForTimeout(60);
      const ok1 = await p.evaluate(() => !!document.querySelector('.sheet'));
      if (ok1) { await p.evaluate(() => document.getElementById('pv-read').click()); await p.waitForTimeout(80); }
      const ok2 = await p.evaluate(() => !!document.querySelector('.screen'));
      if (!ok1 || !ok2 || errs.length) fails.push(`${s.id} save=${save}: page=${ok1} chat=${ok2} ${errs.join('; ')}`);
    }
  }
  for (const t of ['home', 'fav', 'search', 'menu']) { errs.length = 0; await p.evaluate(t => { document.querySelector('.screen')?.remove(); document.querySelector('.sheet')?.remove(); tab = t; render(); }, t); await p.waitForTimeout(80); if (errs.length) fails.push(`tab ${t}: ${errs.join('; ')}`); }
  await b.close();
  if (fails.length) { console.error('SMOKE FAILED\n  ' + fails.join('\n  ')); process.exit(1); }
  console.log(`smoke ok: ${stories.length} stories x 5 progress states, 4 tabs`);
})();
