// Adds the "chat" section (and, for stage 3, "search", "fear", "favs", "reel", "spot") to ios/SquealTests/web-expected.json: stories walked through in the web prototype itself
// (web/squeal-preview.html in Chromium, time faked so nothing waits), with what is saved and shown after every step.
// The app's ChatReader must come out the same (ios/SquealTests/ChatTests.swift).
// Usage: node ios/tools/web-expected.js     (after python3 web/build.py; needs Playwright's own Chromium)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const file = path.resolve(__dirname, '../SquealTests/web-expected.json');
const url = 'file://' + path.resolve(__dirname, '../../web/squeal-preview.html');

const rep = (x, n) => Array.from({ length: n }, () => x);
const NH = 'nobodys-home', TK = 'two-knocks';
// steps: "tap" (read on), {pick: k} (an answer), "next", "again", {turn: k} (back to a choice), {open: part or null},
//        "back" (leave the chat), "tapback" (tap, then leave before the message comes)
const SCENARIOS = [
  { name: 'five messages, then back', id: NH, steps: [{ open: null }, ...rep('tap', 5), 'back'] },
  { name: 'three messages are no progress once the chat is left', id: NH, steps: [{ open: null }, ...rep('tap', 3), 'back', { open: null }] },
  { name: 'the end of a part, the next part, back to part 1, read again', id: NH, save: { [NH]: { ep: 0, pos: [79, 0, 0] } },
    steps: [{ open: null }, 'tap', 'tap', 'next', ...rep('tap', 4), { open: 0 }, 'again', 'tap', { open: 1 }, 'back'] },
  { name: 'a short visit to another part is dropped on leaving it', id: NH, save: { [NH]: { ep: 0, pos: [30, 0, 0] } },
    steps: [{ open: null }, { open: 1 }, 'tap', 'tap', { open: 2 }, 'tap', { open: 0 }, 'tap', 'back'] },
  { name: 'all read: opens at the end; read again starts the whole story', id: NH, save: { [NH]: { ep: 2, pos: [81, 79, 70] } },
    steps: [{ open: null }, 'again', 'tap', 'back'] },
  { name: 'last part read, part 1 half read: read again wipes this part only', id: NH, save: { [NH]: { ep: 2, pos: [40, 79, 70] } },
    steps: [{ open: 2 }, 'again', 'back', { open: null }] },
  { name: 'an old save { ep, i }', id: NH, save: { [NH]: { ep: 1, i: 12 } }, steps: [{ open: null }, 'tap', 'back'] },
  { name: 'interactive: open it', id: TK, steps: [{ open: null }, ...rep('tap', 16), { pick: 0 }, ...rep('tap', 10), 'back', { open: null }] },
  { name: 'interactive: stay, hide; back to each choice; start over', id: TK,
    steps: [{ open: null }, ...rep('tap', 16), { pick: 1 }, ...rep('tap', 6), { pick: 1 }, ...rep('tap', 8), { turn: 1 }, { pick: 0 }, ...rep('tap', 11),
      { turn: 0 }, 'back', { open: null }, { pick: 0 }, 'tap', 'back', { open: null }, ...rep('tap', 9), 'again', 'tap', 'tap', 'back'] },
  { name: 'interactive: left right after the answer, the reply comes by itself', id: TK, save: { [TK]: { ep: 0, pos: [17], path: ['start', 'stay'] } },
    steps: [{ open: null }, 'tap', 'back'] },
  { name: 'interactive: a saved path with a branch that is gone', id: TK, save: { [TK]: { ep: 0, pos: [20], path: ['start', 'nope'] } }, steps: [{ open: null }, 'tap'] },
  { name: 'interactive: a saved path that jumps a choice', id: TK, save: { [TK]: { ep: 0, pos: [20], path: ['start', 'run'] } }, steps: [{ open: null }] },
  { name: 'interactive: a save with no path', id: TK, save: { [TK]: { ep: 0, pos: [5] } }, steps: [{ open: null }, 'tap'] },
  { name: 'interactive: finished, opened again', id: TK, save: { [TK]: { ep: 0, pos: [37], path: ['start', 'stay', 'hide'] } }, steps: [{ open: null }, 'back'] },
  { name: 'free reader: five taps, then the paywall', id: NH, premium: false, taps: 5, steps: [{ open: null }, ...rep('tap', 7), 'back', { open: null }] },
  { name: 'free reader: a tap is given back when the chat closes before the message comes', id: NH, premium: false, taps: 5,
    steps: [{ open: null }, 'tap', 'tapback', { open: null }, 'tap', 'tap', 'tapback'] },
  { name: 'free reader: an answer costs one tap, its reply none', id: TK, premium: false, taps: 2, save: { [TK]: { ep: 0, pos: [16], path: ['start'] } },
    steps: [{ open: null }, { pick: 1 }, 'tap', 'tap', 'tap'] },
  { name: 'free reader: no taps at a choice', id: TK, premium: false, taps: 0, save: { [TK]: { ep: 0, pos: [16], path: ['start'] } }, steps: [{ open: null }] },
];

(async () => {
  const browser = await chromium.launch();
  const out = [];
  for (const sc of SCENARIOS) {
    const page = await (await browser.newContext({ viewport: { width: 393, height: 852 } })).newPage();
    await page.clock.install();
    await page.addInitScript(sc => {
      if (sessionStorage.getItem('seeded')) return; sessionStorage.setItem('seeded', '1');
      localStorage.clear(); localStorage.setItem('squeal:lang', '"en"');
      for (const k in (sc.save || {})) localStorage.setItem('squeal:p:' + k, JSON.stringify(sc.save[k]));
      if (sc.premium === false) localStorage.setItem('squeal:premium', 'false');
      if (sc.taps != null) localStorage.setItem('squeal:taps', JSON.stringify(sc.taps));
    }, sc);
    await page.goto(url);
    await page.clock.fastForward(1000);
    const read = () => page.evaluate(id => {
      const s = STORIES.find(x => x.id === id), p = prog(s), scr = [...document.querySelectorAll('.screen')].find(x => !x._leaving);
      const foot = scr && scr.querySelector('#foot'), log = scr && scr.querySelector('#log');
      return {
        saved: JSON.parse(localStorage.getItem('squeal:p:' + id) || 'null'),
        ep: p.ep, pos: p.pos, path: p.path || null, pct: progress(s), next: nextPart(s, p),
        taps: store.get('taps', 100),
        open: scr ? scr._ep : null,
        shown: log ? log.querySelectorAll('.msg:not(.draft)').length : null,
        last: log ? ([...log.querySelectorAll('.msg:not(.draft)')].pop()?.textContent ?? null) : null,
        drafts: log ? [...log.querySelectorAll('.draft')].map(x => x.textContent) : null,
        foot: !foot ? null : foot.querySelector('.paywall') ? 'pay' : foot.querySelector('#again') ? 'end' : log.querySelector('.draft') ? 'ask' : 'tap',
        nextButton: foot ? !!foot.querySelector('#next') : null,
        turns: foot ? foot.querySelectorAll('.turn').length : null,
        end: log ? (log.querySelector('.end')?.innerText.replace(/\s*\n\s*/g, ' | ') ?? null) : null,
      };
    }, sc.id);
    const steps = [];
    for (const st of sc.steps) {
      // time jumps (fastForward fires each due timer once): a hop per timer in the chain
      // clicks are sent straight to the control (with time faked the chat's slide-in may still stand off screen)
      const click = sel => page.evaluate(q => { const el = [...document.querySelectorAll('.screen')].filter(x => !x._leaving).pop().querySelector(q); if (!el) throw new Error('not there: ' + q); el.click(); }, sel);
      const hop = async (...ms) => { for (const m of ms) await page.clock.fastForward(m); };
      if (st === 'tap') { await click('#foot'); await hop(12000, 400, 1500); }
      else if (st === 'tapback') { await click('#foot'); await hop(100); await click('#back'); await hop(700, 700); }
      else if (st === 'back') { await click('#back'); await hop(700, 700); }
      else if (st === 'next') { await click('#next'); await hop(700, 700); }
      else if (st === 'again') { await click('#again'); await hop(700, 700); }
      else if (st.pick != null) { await click(`.draft[data-k="${st.pick}"]`); await hop(300, 1100, 12000, 400, 1500); }
      else if (st.turn != null) { await click(`.turn[data-k="${st.turn}"]`); await hop(700, 700); }
      else if ('open' in st) { await page.evaluate(([id, k]) => openStory(id, k == null ? undefined : k), [sc.id, st.open]); await hop(1100, 12000, 400, 1500); }
      steps.push({ do: st, ...(await read()) });
      if (process.env.DEBUG) { const r = steps[steps.length - 1]; console.log(sc.name, JSON.stringify(st), r.shown, r.foot, JSON.stringify(r.pos), r.taps); }
    }
    out.push({ name: sc.name, id: sc.id, save: sc.save || null, premium: sc.premium !== false, taps: sc.taps ?? null, steps });
    await page.context().close();
  }
  // the wallpaper's layout (wallItems) for a few parts: the app must lay the same doodles on the same places
  const wp = await (await browser.newContext()).newPage();
  await wp.goto(url);
  const wall = await wp.evaluate(list => list.map(([id, k]) => {
    const e = STORIES.find(x => x.id === id).episodes[k];
    const cfg = e.wallpaperEndings ? { common: e.wallpaper, endings: e.wallpaperEndings } : e.wallpaper;
    return { id, ep: k, items: wallItems(cfg, id + ':' + k).map(i => [i.name, i.g, i.s, i.px, i.py, i.rot]) };
  }), [[NH, 0], [NH, 2], [TK, 0], ['clown', 0], ['the-doctor', 0]]);
  // a voice message's waveform (voiceBubble): the bar heights the web draws for a clip
  const voiceBars = await wp.evaluate(() => { const d = document.createElement('div'); voiceBubble(d, { voice: 'voice/two-knocks-door.mp3', dur: 10, text: '' });
    return [...d.querySelectorAll('.wave i')].map(i => parseInt(i.style.height)); });

  // ---- stage 3: Search, the fear row, Favourites, the random reel, the one rule for double taps ----
  const QUERIES = ['clown', 'CLOWN', 'clwon', 'clow', 'clo', 'cl', 'nobody', "nobody's", 'nobodys home', 'the', 'doctor', 'docter', 'doctr', 'dcotor', 'knocks', 'two  knocks',
    'tow knocks', 'xyz', ' ', '', 'home', 'hom', 'homee', 'gravee', 'grav', 'reunion', 'réunion', 'haunted', 'hauntd', 'last train', 'train out', 'frenemy', 'frenmy',
    'клоун', 'КЛОУН', 'клуон', 'доктор', 'ёлка', 'елка', 'дом', 'дома', 'стука', 'docteur', 'médecin', 'medecin', 'arzt', 'payaso', 'süß', 'suss', 'cross', 'crossroad', 'croosroad', 'match', 'perfect match', 'perfcet'];
  const search = {};
  for (const lang of ['en', 'de', 'fr', 'es', 'ru']) {
    search[lang] = await wp.evaluate(([lang, qs]) => { setLang(lang); return qs.map(q => [q, searchStories(q).map(s => s.id)]); }, [lang, QUERIES]);
  }
  await wp.evaluate(() => setLang('en'));
  const norm = await wp.evaluate(list => list.map(t => [t, norm(t)]), ["Nobody’s Home", "  Two   Knocks ", 'Süßes — Gift!', 'Ёлка, ёж & Йод', 'Réunion (l’été)', 'A-B_c.d', 'İstanbul ǅ', "it's `ok`", '３ ½ x²']);
  const oneEdit = await wp.evaluate(list => list.map(([a, b]) => [a, b, oneEditAway(a, b)]), [['abc', 'abc'], ['abc', 'abd'], ['abc', 'acb'], ['abc', 'ab'], ['abc', 'abcd'], ['abc', 'xabc'], ['abcd', 'badc'],
    ['abc', 'cba'], ['', 'a'], ['a', ''], ['ab', 'ba'], ['abcd', 'abdc'], ['abcd', 'acbd'], ['abcd', 'abxy'], ['abc', 'abcde'], ['клоун', 'клуон'], ['aa', 'aaa'], ['abca', 'abac']]);
  const fear = await wp.evaluate(() => [1, 2, 3, 4, 5].map(l => STORIES.filter(s => fearOf(s) === l).map(s => s.id)));
  // the fear row's look for a few scroll positions (px past the first name standing in the middle)
  const fp = await (await browser.newContext({ viewport: { width: 393, height: 852 } })).newPage();
  await fp.addInitScript(() => { localStorage.clear(); localStorage.setItem('squeal:lang', '"en"'); localStorage.setItem('squeal:tab', '"search"'); });
  await fp.goto(url); await fp.waitForTimeout(600);
  const paint = [];
  for (const x of [0, 30, 66, 67, 132, 200, 264, 300, 396, 461, 528]) {
    paint.push(await fp.evaluate(async x => { const lv = document.querySelector('.fear .lv'); lv.style.scrollSnapType = 'none'; lv.scrollLeft = x; await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
      const b = [...lv.querySelectorAll('button')]; return { x: lv.scrollLeft, s: b.map(n => +n.style.getPropertyValue('--s')), o: b.map(n => +n.style.getPropertyValue('--o')) }; }, x));
  }
  await fp.context().close();
  // Favourites: what stands under which heading, for a few sets of likes (in the order they were liked)
  const favs = [];
  for (const set of [['clown', 'the-doctor', 'two-knocks'], ['two-knocks', 'clown', 'frenemy', 'nobodys-home', 'grave'], ['frenemy'], [], ['reunion', 'haunted', 'gone-now-what'], ['no-such-story', 'clown']]) {
    const p = await (await browser.newContext({ viewport: { width: 393, height: 852 } })).newPage();
    await p.addInitScript(set => { localStorage.clear(); localStorage.setItem('squeal:lang', '"en"'); localStorage.setItem('squeal:tab', '"fav"'); localStorage.setItem('squeal:favs', JSON.stringify(set)); }, set);
    await p.goto(url); await p.waitForTimeout(400);
    favs.push({ favs: set, rows: await p.evaluate(() => [...document.querySelectorAll('#view > .label, #view > .row-card')].map(e => e.classList.contains('label') ? '#' + e.textContent : e.dataset.id), ),
      empty: await p.evaluate(() => !!document.querySelector('.empty')) });
    await p.context().close();
  }
  // the random reel: the candidates it holds (deal()) for a genre and some reading done, and where it stands for a pull
  const reel = [];
  const allRead = await wp.evaluate(() => Object.fromEntries(STORIES.map(s => ['p:' + s.id, { ep: 0, pos: s.episodes.map(() => 9999), v: s.v }])));
  const someRead = await wp.evaluate(() => Object.fromEntries(STORIES.filter((s, i) => i % 2 === 0).map(s => ['p:' + s.id, { ep: 0, pos: s.episodes.map(() => 9999), v: s.v }])));
  const halfHorror = await wp.evaluate(() => Object.fromEntries(STORIES.filter(s => s.genre === 'horror').map((s, i) => ['p:' + s.id, { ep: 0, pos: s.episodes.map((e, k) => k === 0 ? (i % 2 ? 9999 : 8) : (i % 2 ? 9999 : 0)), v: s.v }])));
  const romanceLeft1 = await wp.evaluate(() => Object.fromEntries(STORIES.filter(s => s.genre === 'romance').slice(1).map(s => ['p:' + s.id, { ep: 0, pos: s.episodes.map(() => 9999), v: s.v }])));
  for (const [name, genre, save] of [['nothing read', 'all', {}], ['nothing read', 'horror', {}], ['nothing read', 'romance', {}], ['all read', 'all', allRead], ['all read', 'thriller', allRead],
    ['every other read', 'all', someRead], ['every other read', 'thriller', someRead], ['horror: read or begun', 'horror', halfHorror], ['one romance left', 'romance', romanceLeft1]]) {
    const p = await (await browser.newContext({ viewport: { width: 393, height: 852 }, hasTouch: true })).newPage();
    await p.addInitScript(save => { localStorage.clear(); localStorage.setItem('squeal:lang', '"en"'); for (const k in save) localStorage.setItem('squeal:' + k, JSON.stringify(save[k])); }, save);
    await p.goto(url); await p.waitForTimeout(500);
    reel.push(await p.evaluate(async ([name, genre]) => {
      if (genre !== 'all') { document.getElementById('g-' + genre).dispatchEvent(new MouseEvent('click', { detail: 0, bubbles: true })); await new Promise(r => setTimeout(r, 500)); }
      const view = document.getElementById('view'), tabs = document.querySelector('.tabs'); view.scrollTop = view.scrollHeight; await new Promise(r => setTimeout(r, 100));
      const touch = (type, y) => view.dispatchEvent(new TouchEvent(type, { bubbles: true, cancelable: true, touches: type === 'touchend' ? [] : [new Touch({ identifier: 1, target: view, clientX: 200, clientY: y })] }));
      const hint = document.getElementById('pull-hint').getBoundingClientRect(), last = Math.max(...[...view.querySelectorAll('.tile')].map(t => t.getBoundingClientRect().bottom));
      const T = tabs.getBoundingClientRect().top, rTop = document.querySelector('.rnd').getBoundingClientRect().top;
      touch('touchstart', 700);
      const at = [];
      for (const raw of [5, 10, 11, 40, 60, 99, 100, 101, 150, 260, 400, 300, 200, 100, 50]) { touch('touchmove', 700 - raw);
        at.push({ raw, top: parseFloat(document.querySelector('.slot').style.getPropertyValue('--top')) + rTop, shift: -new DOMMatrix(getComputedStyle(view).transform).m42, hint: document.getElementById('pull-hint').textContent,
          strip: -new DOMMatrix(getComputedStyle(document.querySelector('.strip')).transform).m42 }); }
      const rows = [...document.querySelectorAll('.strip .row b')].map(b => b.textContent), n = rows.length / 8;
      const pool = rows.slice(0, n).map(t => STORIES.find(s => s.title === t).id).sort();
      return { name, genre, pool, n, tabsTop: T, hintBottom: hint.bottom, hintGap: Math.max(8, hint.top - last), at };
    }, [name, genre]));
    reel[reel.length - 1].save = save;
    await p.context().close();
  }
  // the one rule for double taps (SPOT): real clicks on three buttons and the empty space round them, time faked
  const A = [118, 130], B = [132, 130];
  const TAPS = [
    [{ at: [70, 130] }, { ms: 200, at: [70, 130] }],
    [{ at: A }, { ms: 200, at: B }],
    [{ at: A }, { ms: 900, at: B }],
    [{ at: [100, 130] }, { ms: 200, at: [145, 130] }],
    [{ at: [70, 300] }, { ms: 200, at: [75, 300] }],
    [{ at: [70, 155] }, { ms: 200, at: [70, 165] }],
    [{ at: [70, 165] }, { ms: 200, at: [70, 155] }],
    [{ at: A }, { ms: 200, at: B }, { ms: 200, at: B }, { ms: 500, at: B }, { ms: 100, at: B }],
    [{ at: [40, 130], to: [100, 130] }, { ms: 100, at: B }],
    [{ at: [110, 130], to: [117, 130] }, { ms: 100, at: B }],
    [{ at: A }, { ms: 650, at: B }],
    [{ at: A }, { ms: 950, at: B }],
    [{ at: [100, 130] }, { ms: 100, at: [138, 130] }],
    [{ at: [100, 130] }, { ms: 100, at: [142, 130] }],
    [{ at: [70, 158] }, { ms: 300, at: [70, 172] }, { ms: 300, at: [70, 158] }, { ms: 300, at: [70, 158] }],
    [{ at: [70, 300] }, { ms: 300, at: [70, 228] }, { ms: 1000, at: [70, 228] }, { ms: 100, at: [70, 232] }, { ms: 100, at: [70, 232] }],
  ];
  const spot = [];
  for (const taps of TAPS) {
    const p = await (await browser.newContext({ viewport: { width: 393, height: 852 } })).newPage();
    await p.clock.install();
    await p.goto(url); await p.clock.fastForward(1000);
    await p.evaluate(() => { const o = document.createElement('div'); o.id = 'spot-test'; o.style.cssText = 'position:fixed;inset:0;z-index:99999;background:#000';
      o.innerHTML = [['a', 20, 100], ['b', 130, 100], ['c', 20, 170]].map(([n, x, y]) => `<button data-n="${n}" style="position:absolute;left:${x}px;top:${y}px;width:100px;height:60px;padding:0;background:#333"></button>`).join('');
      document.body.appendChild(o); window.GOT = []; o.addEventListener('click', e => window.GOT.push(e.target.dataset.n || null)); });
    const out = [];
    for (const t of taps) {
      if (t.ms) await p.clock.fastForward(t.ms);
      await p.evaluate(() => { window.GOT = []; });
      await p.mouse.move(t.at[0], t.at[1]); await p.mouse.down();
      if (t.to) await p.mouse.move(t.to[0], t.to[1], { steps: 4 });
      await p.mouse.up();
      const got = await p.evaluate(() => window.GOT);
      out.push({ ms: t.ms || 0, at: t.at, to: t.to || null, got: got.length > 0 });
    }
    spot.push(out);
    await p.context().close();
  }
  await browser.close();
  const all = JSON.parse(fs.readFileSync(file, 'utf8'));
  all.chat = out;
  all.wall = wall;
  all.voiceBars = voiceBars;
  Object.assign(all, { search, norm, oneEdit, fear, fearPaint: paint, favs, reel, spot, spotButtons: { a: [20, 100, 100, 60], b: [130, 100, 100, 60], c: [20, 170, 100, 60] } });
  fs.writeFileSync(file, JSON.stringify(all, null, 1) + '\n');
  console.log(out.length + ' scenarios, ' + out.reduce((a, s) => a + s.steps.length, 0) + ' steps');
})();
