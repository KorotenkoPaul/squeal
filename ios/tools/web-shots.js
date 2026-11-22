// Reference screenshots of the web prototype's chat, in the same fixed states as the app's CI screenshots
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
];

(async () => {
  const browser = await chromium.launch();
  for (const st of STATES) {
    const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
    const page = await ctx.newPage();
    await page.addInitScript(({ lang, save }) => {
      localStorage.clear(); localStorage.setItem('squeal:lang', JSON.stringify(lang));
      for (const k in save) localStorage.setItem('squeal:' + k, JSON.stringify(save[k]));
    }, st);
    await page.goto(page_url);
    await page.waitForTimeout(700);
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
