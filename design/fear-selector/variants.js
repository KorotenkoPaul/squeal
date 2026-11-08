// Five compact designs for the fear selector on the Search tab (mockups, level 3 "Scary" selected).
// Injected over the real web preview by shoot.js; the current half-round dial is shot as "0-current".
module.exports = (lvl, FEAR, COL, count) => {
  const name = FEAR[lvl - 1], col = COL[lvl - 1], sub = `${count} ${count === 1 ? 'story' : 'stories'}`;
  const head = `<div class="fx-head"><b style="color:${col}">${name}</b><span>${sub}</span></div>`;
  const css = `
  .fx { flex: none; padding: 4px 2px 6px; }
  .fx-head { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 10px; }
  .fx-head b { font-size: 19px; font-weight: 800; letter-spacing: .01em; }
  .fx-head span { color: var(--muted); font-size: 13px; }
  /* 1 segmented bar */
  .fx1 .seg { display: grid; grid-template-columns: repeat(5, 1fr); gap: 4px; height: 30px; }
  .fx1 .seg i { border-radius: 8px; display: grid; place-items: center; font-style: normal; font-size: 12px; font-weight: 800; color: rgba(255,255,255,.55); }
  /* 2 slider */
  .fx2 .track { position: relative; height: 6px; border-radius: 3px; margin: 8px 10px 4px; background: rgba(255,255,255,.08); }
  .fx2 .fill { position: absolute; inset: 0 auto 0 0; border-radius: 3px; background: linear-gradient(90deg, ${COL[0]}, ${col}); }
  .fx2 .tick { position: absolute; top: 50%; width: 6px; height: 6px; margin: -3px 0 0 -3px; border-radius: 50%; background: rgba(255,255,255,.35); }
  .fx2 .knob { position: absolute; top: 50%; width: 24px; height: 24px; margin: -12px 0 0 -12px; border-radius: 50%; background: #fff; box-shadow: 0 0 0 5px ${col}55, 0 2px 8px rgba(0,0,0,.4); }
  .fx2 .ends { display: flex; justify-content: space-between; color: var(--muted); font-size: 11px; letter-spacing: .06em; text-transform: uppercase; margin-top: 12px; }
  /* 3 mini dial in a row */
  .fx3 { display: flex; align-items: center; gap: 16px; background: var(--field); border-radius: 16px; padding: 12px 16px; }
  .fx3 svg { width: 104px; flex: none; }
  .fx3 .txt { display: flex; flex-direction: column; gap: 2px; flex: 1; }
  .fx3 .txt b { font-size: 22px; font-weight: 800; }
  .fx3 .txt span { color: var(--muted); font-size: 13px; }
  .fx3 .arr { display: flex; gap: 8px; }
  .fx3 .arr i { width: 32px; height: 32px; border-radius: 50%; background: rgba(255,255,255,.07); display: grid; place-items: center; font-style: normal; color: #fff; font-size: 18px; }
  /* 4 signal bars */
  .fx4 { display: flex; align-items: flex-end; gap: 18px; }
  .fx4 .bars { display: flex; align-items: flex-end; gap: 6px; height: 46px; flex: none; }
  .fx4 .bars i { width: 16px; border-radius: 5px; }
  .fx4 .txt { display: flex; flex-direction: column; gap: 2px; padding-bottom: 2px; }
  .fx4 .txt b { font-size: 22px; font-weight: 800; line-height: 1; }
  .fx4 .txt span { color: var(--muted); font-size: 13px; }
  /* 5 one-line picker */
  .fx5 { display: flex; flex-direction: column; align-items: center; gap: 8px; }
  .fx5 .row { width: 100%; display: flex; align-items: center; justify-content: space-between; }
  .fx5 .row i { width: 40px; height: 40px; border-radius: 50%; background: var(--field); display: grid; place-items: center; font-style: normal; font-size: 20px; color: #fff; }
  .fx5 .mid { display: flex; flex-direction: column; align-items: center; gap: 2px; }
  .fx5 .mid small { color: var(--muted); font-size: 11px; letter-spacing: .08em; text-transform: uppercase; }
  .fx5 .mid .side { color: rgba(255,255,255,.22); font-size: 14px; font-weight: 700; }
  .fx5 .names { display: flex; align-items: baseline; gap: 18px; }
  .fx5 .names b { font-size: 24px; font-weight: 800; }
  .fx5 .dots { display: flex; gap: 6px; } .fx5 .dots i { width: 6px; height: 6px; border-radius: 3px; background: #4a4670; }
  `;
  const seg = FEAR.map((n, i) => `<i style="background:${i < lvl ? COL[i] : 'rgba(255,255,255,.07)'};${i === lvl - 1 ? 'box-shadow:0 0 0 2px #fff inset;color:#fff' : i < lvl ? 'color:rgba(255,255,255,.75)' : ''}">${i + 1}</i>`).join('');
  const pos = k => (k / 4 * 100).toFixed(1) + '%';
  const ticks = FEAR.map((_, i) => `<span class="tick" style="left:${pos(i)}"></span>`).join('');
  // mini dial: same drawing as the current one, small
  const R = 44, C = [52, 50], pt = d => [C[0] + R * Math.cos(d * Math.PI / 180), C[1] - R * Math.sin(d * Math.PI / 180)];
  const [ax, ay] = pt(180), [bx, by] = pt(0), deg = 180 - (lvl - 1) * 45, [nx, ny] = pt(deg).map((v, i) => i ? C[1] - (C[1] - v) * .75 : C[0] + (v - C[0]) * .75);
  const dial = `<svg viewBox="0 0 104 58"><defs><linearGradient id="fg3" x1="0" x2="1"><stop offset="0" stop-color="#7b57c9"/><stop offset=".55" stop-color="#a0608f"/><stop offset="1" stop-color="#b5525b"/></linearGradient></defs>
    <path d="M${ax} ${ay} A${R} ${R} 0 0 1 ${bx} ${by}" fill="none" stroke="rgba(255,255,255,.08)" stroke-width="9" stroke-linecap="round"/>
    <path d="M${ax} ${ay} A${R} ${R} 0 0 1 ${bx} ${by}" fill="none" stroke="url(#fg3)" stroke-width="9" stroke-linecap="round" pathLength="100" stroke-dasharray="${(lvl - 1) / 4 * 100} 100"/>
    <line x1="${C[0]}" y1="${C[1]}" x2="${nx.toFixed(1)}" y2="${ny.toFixed(1)}" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/><circle cx="${C[0]}" cy="${C[1]}" r="5" fill="#fff"/></svg>`;
  const bars = FEAR.map((_, i) => `<i style="height:${14 + i * 8}px;background:${i < lvl ? COL[i] : 'rgba(255,255,255,.08)'}"></i>`).join('');
  return { css, v: {
    '1-segments': `<section class="fx fx1">${head}<div class="seg">${seg}</div></section>`,
    '2-slider': `<section class="fx fx2">${head}<div class="track"><span class="fill" style="width:${pos(lvl - 1)}"></span>${ticks}<span class="knob" style="left:${pos(lvl - 1)}"></span></div><div class="ends"><span>${FEAR[0]}</span><span>${FEAR[4]}</span></div></section>`,
    '3-mini-dial': `<section class="fx fx3">${dial}<div class="txt"><b style="color:${col}">${name}</b><span>${sub}</span></div><div class="arr"><i>‹</i><i>›</i></div></section>`,
    '4-signal': `<section class="fx fx4"><div class="bars">${bars}</div><div class="txt"><b style="color:${col}">${name}</b><span>${sub}</span></div></section>`,
    '5-picker': `<section class="fx fx5"><div class="row"><i>‹</i><div class="mid"><small>How scary</small><div class="names"><span class="side">${FEAR[lvl - 2]}</span><b style="color:${col}">${name}</b><span class="side">${FEAR[lvl]}</span></div></div><i>›</i></div><div class="dots">${FEAR.map((_, i) => `<i style="${i === lvl - 1 ? `width:18px;background:${col}` : ''}"></i>`).join('')}</div><small style="color:var(--muted);font-size:13px">${sub}</small></section>`,
  } };
};
