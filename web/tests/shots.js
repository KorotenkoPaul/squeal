// Screenshots of every screen on an iPhone-sized page, to look at after a design change.
// Run: node web/tests/shots.js [out-dir]   (default: /tmp/squeal-shots); sizes: iPhone 16 (393×852) and SE (375×667)
const { chromium } = require('playwright');
const path = require('path'), fs = require('fs');
const { pageUrl, PHONES, phone, watch, sleep } = require('./lib');
const OUT = process.argv[2] || '/tmp/squeal-shots';
const ONLY = process.env.ONLY ? process.env.ONLY.split(',') : null;
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch(), url = pageUrl();
  const sizes = process.env.SIZES ? process.env.SIZES.split(',') : ['iphone16', 'iphoneSE'];
  for (const sz of sizes) {
    const ctx = await phone(b, PHONES[sz]), p = await ctx.newPage(), errs = watch(p);
    const fresh = async (setup = {}) => {
      await p.goto(url); await p.evaluate(s => { localStorage.clear(); for (const [k, v] of Object.entries(s)) localStorage.setItem('squeal:' + k, JSON.stringify(v)); }, setup);
      await p.goto(url); await p.waitForFunction(() => document.getElementById('app').classList.contains('shown') || !document.getElementById('app').classList.contains('boot'), null, { timeout: 4000 }).catch(() => {});
      await sleep(900); };
    const shot = async name => { if (ONLY && !ONLY.includes(name)) return; await p.screenshot({ path: path.join(OUT, `${sz}-${name}.png`) }); };
    const base = { premium: true, lang: 'en' };
    // home
    await fresh({ ...base, favs: ['two-knocks', 'grave'], 'p:nobodys-home': { ep: 0, pos: [20, 0, 0] } }); await shot('home');
    await p.evaluate(() => document.getElementById('view').scrollTo(0, 99999)); await sleep(600); await shot('home-bottom');
    // preview: one part, many parts
    await fresh(base); await p.evaluate(() => preview('two-knocks')); await sleep(1300); await shot('preview');
    await p.evaluate(() => { document.querySelector('.sheet')?.remove(); preview('nobodys-home'); }); await sleep(1300); await shot('preview-parts');
    // chat, part way
    await fresh({ ...base, 'p:nobodys-home': { ep: 0, pos: [14, 0, 0] } }); await p.evaluate(() => openStory('nobodys-home', 0)); await sleep(1800); await shot('chat');
    await p.mouse.click(200, 400); await sleep(250); await shot('chat-typing');
    // interactive: at a choice
    await fresh(base);
    await p.evaluate(() => { const s = STORIES.find(x => x.id === 'two-knocks'), e = s.episodes[0];
      localStorage.setItem('squeal:p:two-knocks', JSON.stringify({ ep: 0, pos: [e.nodes[e.start].messages.length], path: [e.start], v: s.v })); openStory('two-knocks', 0); });
    await sleep(2600); await shot('chat-choice');
    // a finished story: its end
    await fresh({ ...base });
    await p.evaluate(() => { const s = STORIES.find(x => x.id === 'nobodys-home'); localStorage.setItem('squeal:p:nobodys-home', JSON.stringify({ ep: s.episodes.length - 1, pos: s.episodes.map(e => e.messages.length), v: s.v })); openStory('nobodys-home', s.episodes.length - 1); });
    await sleep(1800); await shot('chat-end');
    // paywall
    await fresh({ premium: false, lang: 'en', taps: 0, 'p:grave': { ep: 0, pos: [6] } }); await p.evaluate(() => openStory('grave', 0)); await sleep(1500); await shot('chat-paywall');
    // favourites, full and empty
    await fresh({ ...base, tab: 'fav', favs: ['two-knocks', 'grave', 'clown', 'the-doctor', 'haunted'] }); await shot('favourites');
    await fresh({ ...base, tab: 'fav' }); await sleep(1500); await shot('favourites-empty');
    // search: dial, typing, nothing found
    await fresh({ ...base, tab: 'search' }); await shot('search');
    await p.click('#q'); await p.keyboard.type('gra'); await sleep(500); await shot('search-typing');
    await p.keyboard.type('zzzz'); await sleep(500); await shot('search-none');
    // menu and languages
    await fresh({ ...base, tab: 'menu' }); await shot('menu');
    await p.evaluate(() => [...document.querySelectorAll('.m-row')].find(b => /Language/.test(b.textContent))?.click()); await sleep(900); await shot('menu-lang');
    // Russian home
    await fresh({ ...base, lang: 'ru' }); await shot('home-ru');
    if (errs.length) console.log(sz, 'ERRORS', errs.slice(0, 5));
    await ctx.close();
  }
  console.log('shots in', OUT); await b.close();
})();
