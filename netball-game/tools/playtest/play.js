// Plays the Web build in Chromium as a phone tester would: touch emulation, landscape, Low graphics.
// Usage: node tools/playtest/play.js URL OUT_DIR WIDTH HEIGHT SCENARIO
//   SCENARIO: tour (every screen), quick (a Quick Match played with the touch controls), cup, league, cup_match
// Needs Playwright (preinstalled: PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers); the game served over http.
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const [url, out, w, h, scenario] = process.argv.slice(2);
const W = +w, H = +h;
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, hasTouch: true, isMobile: false, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  const log = [];
  page.on('console', m => { const t = m.text(); if (/ERROR|SCRIPT|error/i.test(t)) log.push(t); });
  const cdp = await ctx.newCDPSession(page);
  let n = 0;
  const shot = async (name) => { await page.screenshot({ path: `${out}/${String(++n).padStart(2, '0')}_${name}.png` }); };
  // The game's canvas is laid out 1280 wide by default; it expands to the window's shape (stretch aspect expand),
  // so a point in game units is (x * k, y * k) with k = H / 720 when the window is wider than 16:9.
  const k = Math.min(W / 1280, H / 720);
  const gx = (x) => x * k, gy = (y) => y * k;
  const touch = async (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map((p, i) => ({ x: p[0], y: p[1], id: p[2] ?? i })) });
  const tap = async (x, y) => { await touch('touchStart', [[x, y]]); await sleep(60); await touch('touchEnd', []); await sleep(250); };
  const drag = async (x0, y0, x1, y1, ms = 600, id = 0) => {
    await touch('touchStart', [[x0, y0, id]]);
    const steps = 12;
    for (let i = 1; i <= steps; i++) { await touch('touchMove', [[x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps, id]]); await sleep(ms / steps); }
    await touch('touchEnd', []);
  };
  // Hold the joystick in a direction while tapping a button with another finger.
  const holdStick = async (dx, dy, ms) => {
    const bx = gx(170), by = H - gy(170);
    await touch('touchStart', [[bx, by, 1]]);
    await touch('touchMove', [[bx + dx * 80, by + dy * 80, 1]]);
    await sleep(ms);
    await touch('touchEnd', []);
  };
  // The match's buttons: the first big in the bottom right corner, the others round it (game units).
  const btn = (i) => {
    const sw = W / k, sh = H / k;
    const cx = sw - 30 - 104, cy = sh - 30 - 104;
    const pl = [[cx, cy], [cx - 178, cy + 6], [cx - 60, cy - 170], [cx - 190, cy - 150]][i];
    return [gx(pl[0]), gy(pl[1])];
  };

  await page.goto(url, { waitUntil: 'load' });
  await sleep(25000);
  await shot('home');
  const S = scenario;
  if (S === 'tour') {
    // Settings (gear, top right), How to Play tabs, Quick setup, Cup, Records, language picker.
    const sw = W / k;
    await tap(gx(sw - 34 - 29), gy(34 * 0.6 + 29 + 20)); await sleep(1500); await shot('settings');
    await drag(W * 0.5, H * 0.8, W * 0.5, H * 0.3, 500); await sleep(800); await shot('settings_scrolled');
    await page.keyboard.press('Escape'); await sleep(1000);
    await tap(gx(sw - 34 - 29 - 70), gy(64)); await sleep(1500); await shot('records');
    await page.keyboard.press('Escape'); await sleep(1000);
    await tap(gx(sw - 34 - 29 - 140), gy(64)); await sleep(1500); await shot('language');
    await page.keyboard.press('Escape'); await sleep(1500); await shot('language_closed');
    await tap(W * 0.85, H * 0.6); await sleep(1500); await shot('howto');
    await drag(W * 0.5, H * 0.75, W * 0.5, H * 0.35, 500); await sleep(800); await shot('howto_scrolled');
    await page.keyboard.press('Escape'); await sleep(1000);
    await tap(W * 0.18, H * 0.5); await sleep(1500); await shot('cup');
    await page.keyboard.press('Escape'); await sleep(1000);
    await tap(W * 0.18, H * 0.82); await sleep(1500); await shot('league');
    await page.keyboard.press('Escape'); await sleep(1000);
    await tap(W * 0.5, H * 0.6); await sleep(1500); await shot('quick_setup');
  } else if (S === 'quick' || S === 'cup_match') {
    if (S === 'quick') {
      await tap(W * 0.5, H * 0.6); await sleep(1500); await shot('quick_setup');
      await tap(W * 0.5, H - gy(50)); await sleep(6000);
    }
    await playMatch();
  } else if (S === 'cup') {
    await tap(W * 0.18, H * 0.5); await sleep(1500); await shot('cup_pick');
    await tap(W * 0.3, H * 0.45); await sleep(2000); await shot('cup_hub');
    // Play (the lime button on the next-match card, right side).
    await tap(W - gx(150), gy(185)); await sleep(6000);
    await playMatch();
    await tap(W - gx(120), H - gy(50)); await sleep(2000); await shot('cup_after');
  } else if (S === 'league') {
    // The Club Season: the lower half of the left third.
    await tap(W * 0.18, H * 0.82); await sleep(1500); await shot('league_pick');
    await tap(W * 0.2, gy(220)); await sleep(2000); await shot('league_hub');
    await tap(W - gx(150), gy(185)); await sleep(6000);
    await playMatch();
    await tap(W - gx(120), H - gy(50)); await sleep(2000); await shot('league_after');
  }
  async function playMatch() {
    const state = async () => page.evaluate(() => window.cpn || {});
    let last = '', shots = 0, t0 = Date.now(), passes = 0;
    while (Date.now() - t0 < 1500000) {
      const st = await state();
      if (st.phase === 'result') { await sleep(1500); await shot('result'); break; }
      if (st.phase === 'break' || st.phase === 'timeout' || st.phase === 'injury') {
        await shot(`break_q${st.q}`);
        await tap(W - gx(200), H - gy(60)); await sleep(1500); continue;
      }
      const b = st.buttons || [];
      if (b.includes('SHOOT')) { await tap(...btn(0)); await sleep(1500); }
      else if (b.includes('PASS')) {
        const dir = [[1, 0], [0.8, -0.5], [0.8, 0.5]][passes++ % 3];
        await holdStick(dir[0], dir[1], 250); await tap(...btn(0)); }
      else if (b.includes('INTERCEPT')) {
        await holdStick(Math.random() * 2 - 1, Math.random() * 2 - 1, 600);
        await tap(...btn(Math.random() < 0.5 ? 0 : 1)); }
      else { await holdStick(1, 0, 400); }
      const key = `${st.phase}|${st.q}|${(st.score || []).join('-')}`;
      if (key !== last && shots < 40) { last = key; shots++; await shot(`m_${st.phase}_q${st.q}_${(st.score || []).join('-')}`); }
    }
  }
  require('fs').writeFileSync(`${out}/console.txt`, log.join('\n'));
  await browser.close();
})();
