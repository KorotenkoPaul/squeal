// Walk every story to its end, every part, picking answers at random (typing waits shortened, animations real).
// Checked every frame: page errors, a new bubble below the bottom panel, bubbles overlapping, old messages jumping
// down or up, see-through messages, sideways jumps. After each part: progress saved, "Next part", "Read again".
// Run: node web/tests/walk.js  (IDS=a,b  W, H, LANG2=de, SEED). Exits 1 on problems.
const { chromium } = require('playwright');
const { pageUrl, phone, watch } = require('./lib');
const SEED = +(process.env.SEED || 1), W = +(process.env.W || 390), H = +(process.env.H || 800), LANG = process.env.LANG2 || 'en';
let rs = SEED; const rnd = () => (rs = (rs * 1103515245 + 12345) % 2147483648) / 2147483648;
(async () => { const b = await chromium.launch(); const ctx = await phone(b, { width: W, height: H }); const pg = await ctx.newPage();
  const errs = watch(pg);
  await pg.goto(pageUrl({ fast: true })); await pg.waitForTimeout(700);
  await pg.evaluate(l => { localStorage.setItem('squeal:premium', 'true'); setLang(l); }, LANG);
  const all = await pg.evaluate(() => STORIES.map(s => ({ id: s.id, parts: s.episodes.length })));
  const ids = process.env.IDS ? process.env.IDS.split(',') : all.map(s => s.id);
  await pg.evaluate(() => { window.V = []; window.CTX = ''; let prev = new Map();
    const g = () => { const L = document.querySelector('.screen .log:not(.log-ghost)'); const ghostSw = document.querySelector('.log-ghost');
      if (L && !ghostSw && !document.querySelector('.screen')?.getAnimations().length) { const Lr = L.getBoundingClientRect(), now = performance.now(), cur = new Map();
        const kids = [...L.children].filter(c => c.matches('.msg, .typing') && c.style.visibility !== 'hidden');
        kids.forEach((m, i) => { if (!m._b) m._b = now; const r = m.getBoundingClientRect(), age = now - m._b; cur.set(m, r);
          if (r.bottom - Lr.bottom > 1.5 && age < 500 && r.height > 3 && +getComputedStyle(m).opacity > .05) V.push(`new bubble below the panel by ${(r.bottom - Lr.bottom).toFixed(1)} [${CTX}]`);
          if (i && r.height > 3) { const a = kids[i - 1].getBoundingClientRect(); if (a.bottom - r.top > .8) V.push(`bubble over the one above by ${(a.bottom - r.top).toFixed(1)} [${CTX}] ${m.className}`); }
          if (age > 600 && !m.matches('.draft') && +getComputedStyle(m).opacity < .97 && r.bottom > Lr.top && r.top < Lr.bottom) V.push(`see-through message [${CTX}]`);
          const p = prev.get(m); if (p && age > 450) { const dy = r.top - p.top, dx = r.left - p.left;
            if (dy > (document.querySelector('.draft.on') ? 7 : 1.5)) V.push(`old message moved down ${dy.toFixed(1)} [${CTX}]`);
            if (dy < -60) V.push(`old message jumped up ${(-dy).toFixed(0)} [${CTX}] newest: ${[...L.children].at(-1).className} ${Math.round([...L.children].at(-1).getBoundingClientRect().height)}px path ${JSON.stringify(JSON.parse(localStorage.getItem('squeal:p:two-knocks') || '{}').path)}`);
            if (Math.abs(dx) > 1.5 && !m.getAnimations().length && Math.abs(parseFloat(m.style.getPropertyValue('--sx') || 0)) < .5) V.push(`message moved sideways ${dx.toFixed(1)} [${CTX}]`); } });
        prev = cur; } else prev = new Map();
      requestAnimationFrame(() => setTimeout(g, 0)); };
    requestAnimationFrame(() => setTimeout(g, 0)); });
  const out = []; const t0 = Date.now();
  for (const id of ids) {
    await pg.evaluate(id => { document.querySelectorAll('.sheet,.screen').forEach(e => e.remove()); localStorage.removeItem('squeal:p:' + id); openStory(id, 0); window.CTX = id; }, id);
    await pg.waitForTimeout(900);
    let taps = 0, picks = 0, parts = 1, guard = 0, ended = false;
    while (guard++ < 2500) {
      const st = await pg.evaluate(() => ({ choice: document.querySelectorAll('.screen .log .draft:not(.on)').length, next: !!document.querySelector('.screen #next'), again: !!document.querySelector('.screen #again'),
        typing: !!document.querySelector('.screen .log .typing'), ghost: !!document.querySelector('.draft.on'), wait: !!document.querySelector('.screen .foot.wait'), pay: !!document.querySelector('#pay'), ep: document.querySelector('.screen')?._ep }));
      if (st.pay) { out.push(`${id}: paywall with premium on`); break; }
      if (st.choice && !st.ghost) { await pg.waitForTimeout(900); const c = await pg.locator('.screen .log .draft').all(); if (c.length) { await c[Math.floor(rnd() * c.length)].click(); picks++; } await pg.waitForTimeout(700); continue; }
      if (st.next && !st.wait) { await pg.evaluate(p => { window.CTX = window.CTX.split(' ')[0] + ' part ' + p; }, parts + 1); await pg.waitForTimeout(650); await pg.click('.screen #next'); parts++; await pg.waitForTimeout(900); continue; }
      if (st.again && !st.next && !st.wait) { ended = true; break; }
      if (!st.typing && !st.ghost) { await pg.touchscreen.tap(W / 2, H * .45); taps++; }
      await pg.waitForTimeout(st.typing ? 120 : 70);
    }
    const pr = await pg.evaluate(id => { const s = STORIES.find(x => x.id === id); return { pct: progress(s), ep: prog(s).ep }; }, id);
    const info = all.find(s => s.id === id);
    if (!ended) out.push(`${id}: did not reach the end (taps ${taps}, part ${parts})`);
    if (ended && parts !== info.parts) out.push(`${id}: ended after ${parts} of ${info.parts} parts`);
    if (ended && pr.pct !== 100) out.push(`${id}: finished but progress shows ${pr.pct}%`);
    // reopen: a finished story opens at its end
    if (ended) { await pg.evaluate(id => { document.querySelectorAll('.screen').forEach(e => e.remove()); openStory(id); }, id); await pg.waitForTimeout(1200);
      const ok = await pg.evaluate(() => !!document.querySelector('.screen #again')); if (!ok) out.push(`${id}: reopened finished story does not show its end`); }
    console.log(`${id}: ${ended ? 'end' : 'STUCK'} — parts ${parts}, taps ${taps}, picks ${picks}, ${Math.round((Date.now() - t0) / 1000)}s`);
  }
  const v = [...new Set(await pg.evaluate(() => V))];
  console.log(`\nwalk seed ${SEED} ${W}x${H} ${LANG}: ${v.length + out.length + errs.length ? 'PROBLEMS' : 'clean'}`);
  [...errs, ...out, ...v].slice(0, 25).forEach(x => console.log('  ' + x));
  await b.close(); process.exit(v.length + out.length + errs.length ? 1 : 0); })();
