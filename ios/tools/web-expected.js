// Adds the "chat" section to ios/SquealTests/web-expected.json: stories walked through in the web prototype itself
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
  await browser.close();
  const all = JSON.parse(fs.readFileSync(file, 'utf8'));
  all.chat = out;
  all.wall = wall;
  all.voiceBars = voiceBars;
  fs.writeFileSync(file, JSON.stringify(all, null, 1) + '\n');
  console.log(out.length + ' scenarios, ' + out.reduce((a, s) => a + s.steps.length, 0) + ' steps');
})();
