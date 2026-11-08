// node design/fear-selector/shoot.js — screenshots of the Search tab with each selector design (iPhone size)
const { chromium } = require('playwright'); const path = require('path');
const variants = require('./variants.js');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  await p.goto('file://' + path.resolve(__dirname, '../../web/squeal-preview.html')); await p.waitForTimeout(500);
  await p.click('#tab-search'); await p.waitForTimeout(400);
  await p.evaluate(() => { const svg = document.querySelector('#fear svg'); const r = svg.getBoundingClientRect();
    const k = r.width / 240, x = r.left + k * (120 + 100 * Math.cos(Math.PI / 2)), y = r.top + k * (124 - 100); });
  // pick level 3 on the real dial
  await p.evaluate(() => { const m = document.querySelector('#fear .mark[data-lvl="3"]'); m && m.dispatchEvent(new Event('click', { bubbles: true })); });
  const info = await p.evaluate(() => ({ FEAR, COL: FEAR_COL, count: STORIES.filter(s => fearOf(s) === 3).length }));
  await p.waitForTimeout(400);
  await p.screenshot({ path: path.join(__dirname, '0-current.png') });
  const { css, v } = variants(3, info.FEAR, info.COL, info.count);
  await p.addStyleTag({ content: css });
  for (const [k, html] of Object.entries(v)) {
    await p.evaluate(h => { const old = document.querySelector('#fear, .fx'); const d = document.createElement('div'); d.innerHTML = h; old.replaceWith(d.firstElementChild);
      document.getElementById('view').scrollTop = 0; }, html);
    await p.waitForTimeout(150);
    await p.screenshot({ path: path.join(__dirname, k + '.png') });
  }
  await b.close();
})();
