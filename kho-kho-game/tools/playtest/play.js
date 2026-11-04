// The phone playtest: plays the browser build in Chromium with touch, as a tester's thumbs would, and takes pictures.
// The game, opened with ?playtest, publishes what is on its screen as window.khoState (game/playtest.gd).
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   npx http-server build/web -p 8060 -s &
//   NODE_PATH=/opt/node-tools/node_modules node tools/playtest/play.js OUT_DIR WIDTHxHEIGHT [classic|fast] [chase|defend] [turns]
//
// It plays a match from the home screen: Quick Match, the rules, the toss, then the turns (chasing: run at the
// nearest defender you may touch or to the seated chaser to kho, KHO when his square lights, DIVE when a defender is
// just out of reach; defending: run away from the active chaser, behind his back), the intervals, the result.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const out = process.argv[2] || '/tmp/playtest';
const [W, H] = (process.argv[3] || '1280x720').split('x').map(Number);
const rules = process.argv[4] || 'classic';
const first = process.argv[5] || 'chase';
const maxTurns = Number(process.argv[6] || 4);
fs.mkdirSync(out, { recursive: true });
const log = (...a) => { const line = `[${new Date().toISOString().slice(11, 19)}] ${a.join(' ')}`; console.log(line); fs.appendFileSync(path.join(out, 'log.txt'), line + '\n'); };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  page.on('console', (m) => { const t = m.text(); if (/error|SCRIPT/i.test(t)) log('console:', t.slice(0, 300)); });
  const cdp = await ctx.newCDPSession(page);
  await page.goto('http://127.0.0.1:8060/index.html?playtest&gfx=0');
  let shot = 0;
  const snap = async (name) => { shot++; const f = path.join(out, `${String(shot).padStart(3, '0')}_${name}.png`); await page.screenshot({ path: f }); log('shot', f); };
  const state = async () => page.evaluate(() => window.khoState || null);
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const touch = async (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map((p, i) => ({ x: p[0], y: p[1], id: p[2] ?? i })) });
  const tap = async (x, y, id = 5) => { await touch('touchStart', [[x, y, id]]); await sleep(60); await touch('touchEnd', []); await sleep(120); };
  const find = (st, words) => st && st.buttons.find((b) => words.some((w) => b.text.toLowerCase().includes(w.toLowerCase())));
  const tapText = async (words, wait = 8000) => {
    const t0 = Date.now();
    while (Date.now() - t0 < wait) {
      const st = await state();
      const b = find(st, words);
      if (b) { const [x, y, w, h] = b.rect; await tap(x + w / 2, y + h / 2); log('tap', JSON.stringify(b.text)); return true; }
      await sleep(250);
    }
    log('NOT FOUND', words.join('/'));
    return false;
  };
  const until = async (fn, wait = 60000) => { const t0 = Date.now(); while (Date.now() - t0 < wait) { const st = await state(); if (st && fn(st)) return st; await sleep(300); } return null; };

  // Home.
  const home = await until((s) => s.screen === 'main_menu' && !s.loading, 180000);
  log('home', home ? 'ok' : 'NEVER');
  await sleep(4000);
  await snap('home');
  await tapText(['Quick Match']);
  await sleep(1500);
  await snap('home_kho_then_setup');
  await until((s) => s.screen === 'match_setup');
  if (rules === 'fast') { await tapText(['Fast']); await sleep(800); }
  await snap('setup');
  await tapText(['Next']);
  await sleep(800);
  await snap('toss');
  await tapText(['Heads']);
  await sleep(2500);
  await snap('toss_result');
  const st0 = await state();
  if (find(st0, ['Chase first'])) await tapText([first === 'chase' ? 'Chase first' : 'Defend first']);
  else await tapText(['Start the match']);
  await until((s) => s.screen === 'match', 60000);
  log('match started');

  // The match.
  let joy = null;          // [baseX, baseY] while the left thumb is down
  const joyAt = (s) => [Math.round(W * 0.15), Math.round(H * 0.72)];
  const stick = async (dx, dy) => {
    const len = Math.hypot(dx, dy) || 1;
    const r = 80;
    const k = Math.min(1, len / 30);
    const p = joyAt();
    if (!joy) { await touch('touchStart', [[p[0], p[1], 1]]); joy = p; await sleep(30); }
    await touch('touchMove', [[p[0] + (dx / len) * r * k, p[1] + (dy / len) * r * k, 1]]);
  };
  const release = async () => { if (joy) { await touch('touchEnd', []); joy = null; } };
  // A button press: the left thumb lifts, the right taps, the left goes down again on the next stick (one finger at a
  // time keeps the touch stream simple; the game takes two at once too, which test_runner checks).
  const tapButton = async (s, id) => {
    const b = (s.match.touch_buttons || []).find((x) => x.id === id);
    if (!b) return false;
    await release();
    await tap(b.at[0], b.at[1], 2);
    log('button', id);
    return true;
  };
  let turnsSeen = new Set();
  let lastShot = 0;
  let lastPhase = '';
  let khoTaps = 0, dives = 0;
  const t0 = Date.now();
  while (Date.now() - t0 < 60 * 60 * 1000) {
    const s = await state();
    if (!s) { await sleep(300); continue; }
    if (s.screen === 'result_screen') { await release(); await sleep(1500); await snap('result'); break; }
    if (s.screen !== 'match' || !s.match) { await sleep(300); continue; }
    const m = s.match;
    if (m.phase !== lastPhase) { log('phase', m.phase, 'turn', m.turn, 'score', JSON.stringify(m.score)); lastPhase = m.phase; await snap(`phase_${m.phase}_t${m.turn}`); }
    if (m.phase === 'interval') {
      await release();
      if (m.turn + 1 >= maxTurns) { log('stopping after', maxTurns, 'turns'); break; }
      await tapText(['Next turn']);
      continue;
    }
    if (m.phase === 'choose') { await release(); await snap('follow_on_question'); await tapText(['Play on as usual']); continue; }
    if (find(s, ['Got it'])) { await release(); await sleep(800); await snap('coach'); await tapText(['Got it']); continue; }
    if (m.phase !== 'play') { await release(); await sleep(250); continue; }
    if (Date.now() - (globalThis.lastPos || 0) > 5000) { globalThis.lastPos = Date.now(); log('pos', m.active_x?.toFixed(1), m.active_z?.toFixed(1), 'dir', m.dir, 'half', m.half, 'foul', m.foul, 'clock', m.clock.toFixed(0), 'score', JSON.stringify(m.score)); }
    turnsSeen.add(m.turn);
    if (Date.now() - lastShot > 12000) { lastShot = Date.now(); await snap(`play_t${m.turn}_${m.chasing === m.user ? 'chase' : 'defend'}`); }
    if (m.chasing === m.user && m.active) {
      // Chase: a defender on my side I may run at, else the kho square on my way.
      const me = m.active;
      let target = null;
      for (const d of m.defenders) {
        const same = Math.sign(d.z || 0.01) === m.half || Math.abs(d.z) < 0.3;
        const ahead = m.dir === 0 || (d.x - m.active_x) * m.dir > -0.3;
        if (same && ahead) { if (!target || Math.hypot(d.at[0] - me[0], d.at[1] - me[1]) < Math.hypot(target[0] - me[0], target[1] - me[1])) target = d.at; }
      }
      if (m.kho_target >= 0) { if (await tapButton(s, 'KHO')) khoTaps++; await sleep(150); continue; }
      if (!target) {
        // The nearest seated chaser ahead whose back is to me (facing the other side), behind him.
        let best = null;
        for (const q of m.squares) {
          if (q.face !== -m.half) continue;
          if (m.dir !== 0 && (q.x - m.active_x) * m.dir < 0.2) continue;
          if (!best || Math.abs(q.x - m.active_x) < Math.abs(best.x - m.active_x)) best = q;
        }
        if (best) target = [best.at[0] - (m.dir || 1) * 8, best.at[1] + m.half * 18];
        else target = [m.dir > 0 ? W * 0.95 : W * 0.05, me[1]];
      }
      const dx = target[0] - me[0], dy = target[1] - me[1];
      const near = m.defenders.some((d) => Math.hypot(d.at[0] - me[0], d.at[1] - me[1]) < 70);
      if (near && Math.random() < 0.08) { if (await tapButton(s, 'DIVE')) dives++; }
      await stick(dx, dy);
    } else if (m.mine) {
      // Defend: away from the active chaser, toward his back.
      const me = m.mine, c = m.active || me;
      let dx = me[0] - c[0], dy = me[1] - c[1];
      dx += -(m.dir || 0) * 60;
      // Keep off the lines: steer toward the middle of the screen when near an edge of the field.
      if (Math.abs(m.mine_z) > m.field.width / 2 - 1.5) dy += -Math.sign(m.mine_z) * 120;
      if (Math.abs(m.mine_x) > m.field.length / 2 - 1.5) dx += -Math.sign(m.mine_x) * 120;
      await stick(dx, dy);
    }
    await sleep(90);
  }
  await release();
  log('done: turns', [...turnsSeen].join(','), 'kho taps', khoTaps, 'dives', dives);
  const st = await state();
  if (st && st.screen === 'result_screen') {
    await sleep(500);
    await snap('result_final');
  }
  await browser.close();
})().catch((e) => { log('ERROR', e.stack || e); process.exit(1); });
