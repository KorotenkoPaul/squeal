// Reference screenshots of the web prototype (the chat, and the stage 3 screens), in the same fixed states as the app's CI screenshots
// (.github/workflows/ios.yml). Usage: node ios/tools/web-shots.js <out-dir> [width height]
// Needs Playwright with its bundled Chromium; reads web/squeal-preview.html (python3 web/build.py builds it).
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || 'web-shots';
const W = +(process.argv[3] || 393), H = +(process.argv[4] || 852);
const page_url = 'file://' + path.resolve(__dirname, '../../web/squeal-preview.html');

// name, language, saved state (localStorage "squeal:*"), story, part, then what to do
const STATES = [
  { name: 'chat-start', lang: 'en', id: 'nobodys-home', part: 0, save: {} },
  { name: 'chat-mid', lang: 'en', id: 'nobodys-home', part: 0, save: { 'p:nobodys-home': { ep: 0, pos: [22, 0, 0] } }, taps: 3 },
  { name: 'chat-part2', lang: 'en', id: 'nobodys-home', part: 1, save: { 'p:nobodys-home': { ep: 1, pos: [0, 9, 0] } } },
  { name: 'chat-choice', lang: 'en', id: 'two-knocks', part: 0, save: { 'p:two-knocks': { ep: 0, pos: [16], path: ['start'] } } },
  { name: 'chat-picked', lang: 'en', id: 'two-knocks', part: 0, save: { 'p:two-knocks': { ep: 0, pos: [16], path: ['start'] } }, pick: 1 },
  { name: 'chat-ending', lang: 'en', id: 'two-knocks', part: 0, save: { 'p:two-knocks': { ep: 0, pos: [37], path: ['start', 'stay', 'hide'] } } },
  { name: 'chat-end-part', lang: 'en', id: 'nobodys-home', part: 0, save: { 'p:nobodys-home': { ep: 0, pos: [999, 0, 0] } } },
  { name: 'chat-paywall', lang: 'en', id: 'nobodys-home', part: 0, save: { 'p:nobodys-home': { ep: 0, pos: [8, 0, 0] }, premium: false, taps: 0 } },
  { name: 'chat-start-ru', lang: 'ru', id: 'nobodys-home', part: 0, save: {} },
  { name: 'chat-choice-ru', lang: 'ru', id: 'two-knocks', part: 0, save: { 'p:two-knocks': { ep: 0, pos: [16], path: ['start'] } } },
  { name: 'chat-ending-ru', lang: 'ru', id: 'two-knocks', part: 0, save: { 'p:two-knocks': { ep: 0, pos: [37], path: ['start', 'stay', 'hide'] } } },
  { name: 'chat-paywall-ru', lang: 'ru', id: 'nobodys-home', part: 0, save: { 'p:nobodys-home': { ep: 0, pos: [8, 0, 0] }, premium: false, taps: 0 } },
  // stage 3: Favourites, Search, Menu, the pulls of Home (tab: the tab shown; run: done in the page before the shot)
  { name: 'fav', lang: 'en', tab: 'fav', save: { favs: ['clown', 'the-doctor', 'two-knocks'], 'p:clown': { ep: 0, pos: [20] } } },
  { name: 'fav-ru', lang: 'ru', tab: 'fav', save: { favs: ['clown', 'the-doctor', 'two-knocks', 'frenemy'], 'p:clown': { ep: 0, pos: [20] } } },
  { name: 'fav-empty', lang: 'ru', tab: 'fav', save: { favs: [] } },
  { name: 'fav-empty-en', lang: 'en', tab: 'fav', save: { favs: [] } },
  { name: 'search', lang: 'en', tab: 'search', save: {} },
  { name: 'search-ru', lang: 'ru', tab: 'search', save: {}, run: 'fearLevel = 5; render()' },
  { name: 'search-level1', lang: 'en', tab: 'search', save: {}, run: 'fearLevel = 1; render()' },
  { name: 'search-typed', lang: 'en', tab: 'search', save: {}, run: 'query = "the"; render()' },
  { name: 'search-typed-ru', lang: 'ru', tab: 'search', save: {}, run: 'query = "дом"; render()' },
  { name: 'search-none', lang: 'en', tab: 'search', save: {}, run: 'query = "xyzzy"; render()' },
  { name: 'menu', lang: 'en', tab: 'menu', save: {} },
  { name: 'menu-ru', lang: 'ru', tab: 'menu', save: {} },
  { name: 'menu-lang', lang: 'en', tab: 'menu', save: {}, run: 'document.querySelector(\'[data-m="lang"]\').click()' },
  { name: 'menu-lang-ru', lang: 'ru', tab: 'menu', save: {}, run: 'document.querySelector(\'[data-m="lang"]\').click()' },
  { name: 'menu-sub-off', lang: 'en', tab: 'menu', save: {}, run: 'document.querySelector(\'[data-m="sub"]\').click()', wait: 600 },
  { name: 'home-pull', lang: 'en', tab: 'home', save: {}, pull: 120 },
  { name: 'home-reel', lang: 'en', tab: 'home', save: {}, reel: 100 },
  { name: 'home-reel-ru', lang: 'ru', tab: 'home', save: {}, reel: 60 },
];
const only = process.env.ONLY;

(async () => {
  const browser = await chromium.launch();
  for (const st of STATES) {
    if (only && !st.name.startsWith(only)) continue;
    const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, hasTouch: !!st.tab });
    const page = await ctx.newPage();
    await page.addInitScript(({ lang, save, tab }) => {
      localStorage.clear(); localStorage.setItem('squeal:lang', JSON.stringify(lang));
      if (tab) localStorage.setItem('squeal:tab', JSON.stringify(tab));
      for (const k in save) localStorage.setItem('squeal:' + k, JSON.stringify(save[k]));
    }, st);
    await page.goto(page_url);
    await page.waitForTimeout(700);
    if (st.tab) {
      if (st.run) await page.evaluate(st.run);
      if (st.pull || st.reel) await page.evaluate(async ({ pull, reel }) => {
        const view = document.getElementById('view');
        if (reel) { view.scrollTop = view.scrollHeight; await new Promise(r => setTimeout(r, 200)); }
        const touch = (type, y) => view.dispatchEvent(new TouchEvent(type, { bubbles: true, cancelable: true, touches: [new Touch({ identifier: 1, target: view, clientX: 200, clientY: y })] }));
        touch('touchstart', 400);
        for (let k = 1; k <= 10; k++) touch('touchmove', 400 + (pull ? pull : -reel) * k / 10);      // the finger stays down for the shot
      }, { pull: st.pull, reel: st.reel });
      await page.waitForTimeout(st.wait || 2600);
      await page.screenshot({ path: path.join(out, `web-${st.name}.png`) });
      await ctx.close();
      continue;
    }
    await page.evaluate(({ id, part }) => {
      const s = STORIES.find(x => x.id === id);
      // the saved version must be the story's own, or the save counts as an old text
      const raw = JSON.parse(localStorage.getItem('squeal:p:' + id) || 'null');
      if (raw) { raw.v = s.v; localStorage.setItem('squeal:p:' + id, JSON.stringify(raw)); }
      openStory(id, part);
      document.querySelector('#undo-test')?.remove();          // the owner's test button is not ported
    }, st);
    await page.waitForTimeout(2600);                            // the doodles have landed
    for (let k = 0; k < (st.taps || 0); k++) { await page.click('#foot'); await page.waitForTimeout(2400); }
    if (st.pick != null) { await page.click(`.draft[data-k="${st.pick}"]`); await page.waitForTimeout(5000); }
    await page.screenshot({ path: path.join(out, `web-${st.name}.png`) });
    await ctx.close();
  }
  await browser.close();
})();
