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
  /* every story's slider title must fit inside its card, on small, normal and large iPhones */
  for (const w of [320, 390, 430]) {
    await p.setViewportSize({ width: w, height: 844 });
    await p.evaluate(() => { document.querySelector('.screen')?.remove(); document.querySelector('.sheet')?.remove(); tab = 'home'; render(); });
    /* every title's own font, also of the stories not on the slider now (else the stand-in font is measured) */
    await p.evaluate(() => Promise.all([...document.fonts].filter(f => /U\+0-FF\b/i.test(f.unicodeRange)).map(f => f.load().catch(() => {})))); await p.waitForTimeout(300);
    const bad = await p.evaluate(() => { const h = document.querySelector('#slider .hero'), tpl = h.cloneNode(true), out = [];
      Object.keys(LETTERING).forEach(id => { const s = STORIES.find(x => x.id === id), L = LETTERING[id];
        tpl.querySelector('.lt').outerHTML; tpl.querySelector('.lt').remove();
        tpl.insertAdjacentHTML('beforeend', `<span class="lt" style="${L.box}"><b class="art" style="${L.css}">${L.html ? L.html(esc(s.title)) : esc(s.title)}</b></span>`);
        tpl.style.cssText = `position:fixed;left:0;top:0;width:${h.offsetWidth}px;height:${h.offsetHeight}px`; document.body.appendChild(tpl);
        if (!fitLettering(tpl)) out.push(id); tpl.remove(); });
      return out; });
    if (bad.length) fails.push(`width ${w}: slider title sticks out for ${bad.join(', ')}`);
  }
  /* chat wallpaper doodles: a part switch makes the old part's doodles fall and the new part's fly in;
     an interactive choice drops the doodles of the endings it closes off (both broke once unnoticed) */
  {
    const p = await b.newPage({ viewport: { width: 390, height: 844 } });
    p.on('pageerror', e => fails.push('doodles: ' + e.message));
    await p.goto('file://' + path.resolve(__dirname, '..', 'squeal-preview.html')); await p.waitForTimeout(300);
    const multi = await p.evaluate(() => STORIES.find(s => s.episodes.length > 1 && s.episodes.every(e => e.wallpaper?.length))?.id);
    if (multi) {
      await p.evaluate(id => openStory(id, 0), multi); await p.waitForTimeout(4200);
      const settled = await p.evaluate(() => !WALL.items.length && document.querySelector('.screen .chat').style.backgroundImage.startsWith('url('));
      await p.evaluate(id => openStory(id, 1), multi); await p.waitForTimeout(120);
      const ph = await p.evaluate(() => WALL.items.reduce((a, d) => (a[d.phase] = (a[d.phase] || 0) + 1, a), {}));
      if (!settled) fails.push(`doodles: ${multi} part 1 never settled into the plain wallpaper`);
      if (!ph.fall) fails.push(`doodles: switching ${multi} to part 2, nothing fell (${JSON.stringify(ph)})`);
      if (!ph.in) fails.push(`doodles: switching ${multi} to part 2, nothing flew in (${JSON.stringify(ph)})`);
    }
    const inter = await p.evaluate(() => STORIES.find(s => s.interactive && s.episodes[0].wallpaperEndings)?.id);
    if (inter) {
      await p.evaluate(id => { const s = STORIES.find(x => x.id === id), e = s.episodes[0];
        localStorage.setItem('squeal:p:' + id, JSON.stringify({ ep: 0, pos: [e.nodes[e.start].messages.length], path: [e.start], v: s.v })); document.querySelector('.screen')?.remove(); WALL.chat = null; openStory(id, 0); }, inter);
      await p.waitForTimeout(4200);
      await p.locator('.screen .choice').first().click(); await p.waitForTimeout(400);
      const fell = await p.evaluate(() => [...new Set(WALL.items.filter(d => d.phase === 'fall').map(d => d.g))]);
      if (!fell.length || fell.includes('*')) fails.push(`doodles: a choice in ${inter} should drop only closed-off endings' doodles, fell: ${JSON.stringify(fell)}`);
    }
    await p.close();
  }
  /* languages: every word of the interface exists in each language, every story in each language is
     there, every screen renders in each language, and the slider titles still fit */
  {
    const p = await b.newPage({ viewport: { width: 320, height: 700 } });
    const errs = []; p.on('pageerror', e => errs.push(e.message));
    await p.goto(url); await p.waitForTimeout(500);
    const langs = await p.evaluate(() => LANGS.map(l => l[0]));
    for (const l of langs) {
      const r = await p.evaluate(l => {
        const out = [], keys = Object.keys(UI.en);
        keys.forEach(k => { if (!(k in UI[l])) out.push('missing word ' + k); });
        if (!STORIES_ALL[l] || STORIES_ALL[l].length !== STORIES_ALL.en.length) out.push('stories missing');
        setLang(l); ['home', 'fav', 'search', 'menu', 'home'].forEach(x => { tab = x; render(); });
        return out;
      }, l);
      await p.waitForTimeout(700);
      const nofit = await p.evaluate(() => [...document.querySelectorAll('#slider .hero:not(.loop)')].filter(h => !fitLettering(h)).map(h => h.dataset.id));
      r.forEach(x => fails.push(`language ${l}: ${x}`)); nofit.forEach(x => fails.push(`language ${l}: slider title of ${x} does not fit at 320`));
    }
    errs.forEach(e => fails.push('languages: page error ' + e));
    await p.evaluate(() => setLang('en'));
    await p.close();
  }
  await b.close();
  if (fails.length) { console.error('SMOKE FAILED\n  ' + fails.join('\n  ')); process.exit(1); }
  console.log(`smoke ok: ${stories.length} stories x 5 progress states, 4 tabs, slider titles fit at 320/390/430, chat doodles fall and fly in, 5 languages`);
})();
