// The phone playtest's menu tour: every screen, through touch alone, at one screen size, with a picture of each.
//   NODE_PATH=/opt/node-tools/node_modules node tools/playtest/menus.js OUT_DIR WIDTHxHEIGHT
// (the build served as for play.js). It checks that every button it needs is on the screen and logs any that is not.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const out = process.argv[2] || '/tmp/playtest-menus';
const [W, H] = (process.argv[3] || '2400x1080').split('x').map(Number);
fs.mkdirSync(out, { recursive: true });
const log = (...a) => { const line = `[${new Date().toISOString().slice(11, 19)}] ${a.join(' ')}`; console.log(line); fs.appendFileSync(path.join(out, 'log.txt'), line + '\n'); };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  page.on('console', (m) => { const t = m.text(); if (/error|SCRIPT/i.test(t)) log('console:', t.slice(0, 300)); });
  const cdp = await ctx.newCDPSession(page);
  await page.goto('http://127.0.0.1:8060/index.html?playtest&gfx=0');
  let shot = 0;
  const snap = async (name) => { shot++; const f = path.join(out, `${String(shot).padStart(2, '0')}_${name}.png`); await page.screenshot({ path: f }); log('shot', f); };
  const state = async () => page.evaluate(() => window.khoState || null);
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const touch = async (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map((p, i) => ({ x: p[0], y: p[1], id: i })) });
  const tap = async (x, y) => { await touch('touchStart', [[x, y]]); await sleep(60); await touch('touchEnd', []); await sleep(200); };
  const drag = async (x, y, dy) => { await touch('touchStart', [[x, y]]); for (let k = 1; k <= 10; k++) { await touch('touchMove', [[x, y + (dy * k) / 10]]); await sleep(30); } await touch('touchEnd', []); await sleep(400); };
  const until = async (fn, wait = 60000) => { const t0 = Date.now(); while (Date.now() - t0 < wait) { const st = await state(); if (st && fn(st)) return st; await sleep(300); } return null; };
  const offScreen = (st) => st.buttons.filter((b) => b.rect[0] < 0 || b.rect[1] < 0 || b.rect[0] + b.rect[2] > W + 1 || b.rect[1] + b.rect[3] > H + 1);
  const tapText = async (words, wait = 8000) => {
    const t0 = Date.now();
    while (Date.now() - t0 < wait) {
      const st = await state();
      const b = st && st.buttons.find((x) => words.some((w) => x.text.toLowerCase().includes(w.toLowerCase())));
      if (b) { const [x, y, w, h] = b.rect; await tap(x + w / 2, y + h / 2); log('tap', JSON.stringify(b.text)); return true; }
      await sleep(250);
    }
    log('NOT FOUND', words.join('/'));
    return false;
  };
  const look = async (name) => {
    await sleep(1200);
    const st = await state();
    const off = st ? offScreen(st) : [];
    log('screen', st && st.screen, 'buttons', st ? st.buttons.length : 0, off.length ? 'OFF SCREEN: ' + off.map((b) => b.text).join(', ') : '');
    await snap(name);
  };

  await until((s) => s.screen === 'main_menu' && !s.loading, 180000);
  await sleep(3000);
  await look('home');
  await tapText(['Quick Match']);
  await until((s) => s.screen === 'match_setup');
  await look('setup');
  await tapText(['Cities']);
  await look('setup_cities');
  await tapText(['Next']);
  await look('toss');
  await tapText(['Heads']);
  await sleep(2500);
  await look('toss_result');
  await page.goBack().catch(() => {});
  await page.goto('http://127.0.0.1:8060/index.html?playtest&gfx=0');
  await until((s) => s.screen === 'main_menu' && !s.loading, 180000);
  await sleep(2000);
  await tapText(['How to Play']);
  await look('howto');
  await drag(W * 0.6, H * 0.75, -H * 0.5);
  await look('howto_scrolled');
  await tapText(['Back', '‹', '<'], 2000) || await tap(68 * W / 1280, 68 * H / 720);
  await sleep(1000);
  await tapText(['Settings']);
  await look('settings');
  await drag(W * 0.5, H * 0.8, -H * 0.5);
  await look('settings_scrolled');
  await page.goto('http://127.0.0.1:8060/index.html?playtest&gfx=0');
  await until((s) => s.screen === 'main_menu' && !s.loading, 180000);
  await sleep(2000);
  await tapText(['Championships']);
  await look('championships');
  await tapText(['City League']);
  await look('league_chosen');
  await tapText(['Start', 'Begin', 'Next'], 3000);
  await look('league_team');
  await tapText(['Start', 'Begin', 'Next'], 3000);
  await look('league_hub');
  await browser.close();
})().catch((e) => { log('ERROR', e.stack || e); process.exit(1); });
