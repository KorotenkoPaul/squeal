// Every screen and flow, driven by real touches on an iPhone-sized page (393×852 and 375×667):
// tabs, slider, genres, preview (parts, like, reset, ✕ and swipes), chat (read on, part switch, back), an interactive
// story through a choice to an ending and "Back to a choice", favourites (hold to like, swipe to remove), search (fear
// dial, typing, nothing found, cancel), menu (5 languages, subscription off → paywall → on), random story, refresh.
// Fails on any page/console error, on a page that ends up off place, or on horizontal overflow.
// Run: node web/tests/flows.js
const { chromium } = require('playwright');
const { pageUrl, PHONES, phone, watch, sleep } = require('./lib');
const fails = [];
const ok = (cond, msg) => { if (!cond) fails.push(msg); };
(async () => {
  const b = await chromium.launch(), url = pageUrl();
  for (const [name, size] of Object.entries(PHONES)) {
    const ctx = await phone(b, size), p = await ctx.newPage(), errs = watch(p), W = size.width, H = size.height;
    const cdp = await ctx.newCDPSession(p);
    const T = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
    const tap = async (x, y, hold = 40) => { await T('touchStart', [{ x, y }]); await sleep(hold); await T('touchEnd', []); };
    const tapEl = async (sel, hold) => { const r = await p.evaluate(s => { const e = document.querySelector(s); if (!e) return null; const q = e.getBoundingClientRect(); return { x: q.left + q.width / 2, y: q.top + q.height / 2 }; }, sel);
      if (!r) { fails.push(`${name}: no ${sel} to tap`); return false; } await tap(r.x, r.y, hold); return true; };
    const drag = async (x0, y0, x1, y1, n = 16, ms = 16) => { await T('touchStart', [{ x: x0, y: y0 }]);
      for (let k = 1; k <= n; k++) { await T('touchMove', [{ x: x0 + (x1 - x0) * k / n, y: y0 + (y1 - y0) * k / n }]); await sleep(ms); } await T('touchEnd', []); };
    const has = sel => p.evaluate(s => !!document.querySelector(s), sel);
    const settled = async (what) => { await sleep(900); const r = await p.evaluate(() => { const o = [], A = document.getElementById('app');
        if (document.documentElement.scrollWidth > innerWidth + 1) o.push('page wider than the screen');
        if (A.style.transform && !document.querySelector('#layer .sheet')) o.push('home left sunk back with no page open');
        document.querySelectorAll('#layer .sheet, #layer .screen').forEach(s => { const q = s.getBoundingClientRect(); if (Math.abs(q.left - A.offsetLeft) > 1 || Math.abs(q.top) > 1) o.push(`${s.className} off place ${q.left | 0},${q.top | 0}`); });
        return o; }); r.forEach(x => fails.push(`${name} ${what}: ${x}`)); };
    const fresh = async (setup = {}) => { await p.goto(url); await p.evaluate(s => { localStorage.clear(); localStorage.setItem('squeal:premium', 'true'); localStorage.setItem('squeal:lang', '"en"');
      for (const [k, v] of Object.entries(s)) localStorage.setItem('squeal:' + k, JSON.stringify(v)); }, setup); await p.goto(url); await sleep(1300); };

    // tabs
    await fresh();
    for (const t of ['fav', 'search', 'menu', 'home']) { await tapEl(`#tab-${t}`); await sleep(400); ok(await p.evaluate(t => tab === t && document.querySelector(`#tab-${t}`).getAttribute('aria-current') === 'page', t), `${name}: tab ${t} did not open`); }
    await settled('tabs');
    // genres: tap Horror, only horror tiles
    await tapEl('#g-horror'); await sleep(700);
    ok(await p.evaluate(() => [...document.querySelectorAll('.tile')].every(t => STORIES.find(s => s.id === t.dataset.id).genre === 'horror')), `${name}: genre filter`);
    await tapEl('#g-all'); await sleep(600);
    // a tile opens its page; ✕ closes it
    const first = await p.evaluate(() => document.querySelector('.tile').dataset.id);
    await tapEl('.tile'); await sleep(700); ok(await has('.sheet'), `${name}: tile did not open its page`);
    await tapEl('#pv-back'); await sleep(700); ok(!(await has('.sheet')), `${name}: ✕ did not close the page`); await settled('close');
    // swipe down and swipe right close it too
    await tapEl('.tile'); await sleep(800); await drag(W / 2, 300, W / 2, 700); await sleep(700); ok(!(await has('.sheet')), `${name}: swipe down did not close`);
    await tapEl('.tile'); await sleep(800); await drag(30, 400, W - 20, 410); await sleep(700); ok(!(await has('.sheet')), `${name}: swipe right did not close`); await settled('swipes');
    // like on the page, then the tile shows the heart
    await tapEl('.tile'); await sleep(800); await tapEl('#pv-like'); await sleep(500);
    ok(await p.evaluate(id => favs().includes(id), first), `${name}: like on the page`);
    await tapEl('#pv-back'); await sleep(700); ok(await p.evaluate(id => !!document.querySelector(`.tile[data-id="${id}"] .fav`), first), `${name}: tile heart after like`);
    // holding a tile unlikes it
    await tap(...await p.evaluate(id => { const r = document.querySelector(`.tile[data-id="${id}"]`).getBoundingClientRect(); return [r.left + 40, r.top + r.height - 40]; }, first), 700); await sleep(600);
    ok(await p.evaluate(id => !favs().includes(id), first), `${name}: hold to unlike`);
    // a part-story: pick part 2, read, part switch in the chat, back
    await p.evaluate(() => preview('nobodys-home')); await sleep(800);
    await tapEl('.part[data-ep="1"]'); await sleep(500); await tapEl('#pv-read'); await sleep(1200);
    ok(await p.evaluate(() => document.querySelector('.screen')?._ep === 1), `${name}: Read opened the picked part`);
    for (let k = 0; k < 4; k++) { await tap(W / 2, H * .45); await sleep(k ? 2200 : 600); }
    ok(await p.evaluate(() => prog(STORIES.find(s => s.id === 'nobodys-home')).pos[1] > 0), `${name}: reading saved no progress`);
    await tapEl('.ep-seg [data-ep="2"]'); await sleep(1500); ok(await p.evaluate(() => document.querySelector('.screen')?._ep === 2), `${name}: part switch`);
    await tapEl('#back'); await sleep(900); ok(!(await has('#layer .screen')) && !(await has('#layer .sheet')), `${name}: back from the chat`); await settled('chat back');
    // interactive: to a choice, pick, to an ending, back to a choice
    await p.evaluate(() => { const s = STORIES.find(x => x.id === 'two-knocks'), e = s.episodes[0];
      localStorage.setItem('squeal:p:two-knocks', JSON.stringify({ ep: 0, pos: [e.nodes[e.start].messages.length], path: [e.start], v: s.v })); preview('two-knocks'); }); await sleep(800);
    await tapEl('#pv-read'); await sleep(2600); ok(await has('.screen .draft'), `${name}: no answers at the choice`);
    let guard = 0;
    while (guard++ < 400 && !(await has('.screen #again'))) {
      if (await has('.screen .draft:not(.on)')) { await sleep(700); await tapEl('.screen .draft:not(.on)'); await sleep(2600); continue; }
      await tap(W / 2, H * .45); await sleep(await has('.screen .typing') ? 1200 : 450);
    }
    ok(await has('.screen #again'), `${name}: interactive story never ended`);
    await sleep(900);
    if (await has('.screen .turn')) { await tapEl('.screen .turn'); await sleep(2400); ok(await has('.screen .draft'), `${name}: back to a choice shows no answers`); }
    else fails.push(`${name}: no "Back to a choice"`);
    await tapEl('#back'); await sleep(900); await settled('interactive');
    // favourites: hold two tiles, open favourites, swipe one away
    await p.evaluate(() => { localStorage.setItem('squeal:favs', '["grave","clown"]'); tab = 'fav'; render(); }); await sleep(700);
    const r0 = await p.evaluate(() => { const r = document.querySelector('.row-card').getBoundingClientRect(); return [r.right - 30, r.top + r.height / 2]; });
    await drag(r0[0], r0[1], r0[0] - 300, r0[1] + 4, 12); await sleep(900);
    ok(await p.evaluate(() => favs().length === 1 && document.querySelectorAll('.row-card').length === 1), `${name}: swipe to remove`);
    await settled('favourites');
    // search: dial to Nightmare, a word, nothing found, cancel
    await tapEl('#tab-search'); await sleep(600);
    const dy = await p.evaluate(() => { const r = document.querySelector('#fear .lv').getBoundingClientRect(); return r.top + r.height / 2; });
    for (let k = 0; k < 3; k++) { await drag(W * .7, dy, W * .2, dy + 2, 10); await sleep(600); }
    ok(await p.evaluate(() => fearLevel === 5), `${name}: fear dial swipe (level ${await p.evaluate(() => fearLevel)})`);
    await tapEl('#q'); await p.keyboard.type('grave'); await sleep(400); ok(await p.evaluate(() => !!document.querySelector('#results [data-id="grave"]')), `${name}: search finds Grave`);
    await p.keyboard.type('zzz'); await sleep(300); ok(await p.evaluate(() => /Nothing found/.test(document.getElementById('results').textContent)), `${name}: nothing found`);
    await tapEl('#s-cancel'); await sleep(700); ok(await p.evaluate(() => !query && !document.getElementById('fear').classList.contains('out')), `${name}: cancel brings the dial back`);
    await settled('search');
    // menu: languages, back; subscription off → paywall; on again
    await tapEl('#tab-menu'); await sleep(500);
    for (const [i, code] of [[1, 'de'], [4, 'ru'], [0, 'en']]) {
      await tapEl('.m-row[data-i="2"]'); await sleep(1100); await tapEl(`.m-row[data-i="${i}"]`); await sleep(1200);
      ok(await p.evaluate(c => LANG === c && document.getElementById('m-title').textContent === trA('tabs')[3] && document.querySelector('#tab-home span').textContent === trA('tabs')[0], code), `${name}: language ${code}`);
    }
    await tapEl('.m-row[data-i="2"]'); await sleep(1100); await drag(40, 400, 260, 405, 8); await sleep(1100);
    ok(await p.evaluate(() => document.querySelector('.m-row').dataset.m === 'sub'), `${name}: swipe back from languages`);
    await tapEl('.m-row[data-i="0"]'); await sleep(600); ok(await p.evaluate(() => !premium() && !document.querySelector('.switch').classList.contains('on')), `${name}: subscription off`);
    await p.evaluate(() => localStorage.setItem('squeal:taps', '0')); await p.evaluate(() => openStory('grave', 0)); await sleep(1500); await tap(W / 2, H * .45); await sleep(700);
    ok(await has('#pay'), `${name}: no paywall at 0 taps`);
    await tapEl('#back'); await sleep(900); await tapEl('.m-row[data-i="0"]'); await sleep(600); ok(await p.evaluate(() => premium()), `${name}: subscription on again`);
    await settled('menu');
    // home: refresh with the owl, then the random story from the bottom
    await tapEl('#tab-home'); await sleep(700);
    await drag(W / 2, 260, W / 2, 520, 24); await sleep(1800); await settled('refresh');
    await p.evaluate(() => document.getElementById('view').scrollTo(0, 1e5)); await sleep(500);
    await drag(W / 2, H - 140, W / 2, 140, 30, 18); await sleep(2200);
    ok(await has('#layer .sheet'), `${name}: random story did not open a page`);
    await tapEl('#pv-back'); await sleep(800); await settled('random');
    errs.forEach(e => fails.push(`${name}: ${e}`));
    await ctx.close();
  }
  await b.close();
  console.log(fails.length ? 'flows PROBLEMS\n  ' + fails.join('\n  ') : 'flows ok: tabs, genres, page open/close/swipes/like, hold-unlike, parts, chat, interactive ending + back to a choice, favourites swipe, search + dial, menu languages + subscription + paywall, refresh, random story — on 2 iPhone sizes');
  process.exit(fails.length ? 1 : 0);
})();
