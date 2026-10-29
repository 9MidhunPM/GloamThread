#!/usr/bin/env node
'use strict';

// Public, ordinary-input browser smoke. No invitations, private profiles or model calls.
// Example: node evidence/web-portal/browser-smoke.cjs --browser chromium \
//   --playwright /absolute/path/to/node_modules/playwright
// Firefox: also pass --browsers-path build/browser-qa/browsers \
//   --xvfb build/browser-qa/xvfb/usr/bin/Xvfb
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');

const ROOT = path.resolve(__dirname, '../..');
const options = {};
for (let index = 2; index < process.argv.length; index += 2) {
  const key = process.argv[index];
  if (!key.startsWith('--') || !process.argv[index + 1]) throw new Error('Use --name value arguments.');
  options[key.slice(2)] = process.argv[index + 1];
}
const browserName = options.browser || 'chromium';
if (!['chromium', 'firefox'].includes(browserName)) throw new Error('Browser must be chromium or firefox.');
const url = options.url || 'https://gloamthread.midhunpm.in/';
const expectedCommit = options.commit || '37f5bff1f056c7811bb84a4260c1f95ee660d03d';
const cycles = Number(options.cycles || 3);
if (!Number.isInteger(cycles) || cycles < 0 || cycles > 100) throw new Error('Cycles must be an integer from 0 to 100.');
const viewport = { width: 1366, height: 768 };
if (options['browsers-path']) process.env.PLAYWRIGHT_BROWSERS_PATH = path.resolve(ROOT, options['browsers-path']);
const screenshotPrefix = `web-portal-${browserName}`;
const reportPath = options.report ? path.resolve(ROOT, options.report) : path.join(__dirname, `${browserName}.json`);
const report = {
  schema_version: 1, recorded_at_utc: new Date().toISOString(),
  browser: browserName, url, expected_commit: expectedCommit, viewport,
  passed: false, checks: {}, screenshots: {}, errors: [], request_failures: [],
  limitations: ['Automated software-rendered input route, not a human playtest or physical GPU/controller/audio test.',
    'No full twenty-wave browser run or complete Story walkthrough is performed by this smoke.'],
};
if (fs.existsSync(reportPath)) {
  const previous = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  if (!previous.passed) report.previous_attempts = [...(previous.previous_attempts || []), {
    recorded_at_utc: previous.recorded_at_utc, build_commit: previous.build?.implementation_commit,
    error: previous.error, failure_state: previous.failure_state, checks: previous.checks,
    trace_summary: previous.state_trace?.slice(-4),
  }];
}
let browser, context, page, xvfb;
let progressTimer;

function saveReport() {
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  if (options.report) return; // A local regression must not replace the public-browser environment record.
  const browsers = {};
  for (const name of ['chromium', 'firefox']) {
    const file = path.join(__dirname, `${name}.json`);
    if (fs.existsSync(file)) {
      const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
      browsers[name] = { passed: saved.passed, recorded_at_utc: saved.recorded_at_utc,
        user_agent: saved.user_agent, runtime: saved.runtime, renderer: saved.renderer,
        build_commit: saved.build?.implementation_commit, viewport: saved.viewport };
    }
  }
  fs.writeFileSync(path.join(__dirname, 'browser-environment.json'), JSON.stringify({
    schema_version: 1, recorded_at_utc: new Date().toISOString(),
    host: { platform: os.platform(), architecture: os.arch(), kernel: os.release(), node: process.version },
    browser_automation: 'Playwright; fresh isolated contexts, public ordinary mouse/keyboard input',
    browser_plugin: 'Not available in this task; regular Playwright used.',
    expected_commit: expectedCommit, browsers,
    claims_excluded: ['physical GPU frame rate', 'audio listening', 'physical controllers', 'human enjoyment', 'paid Forge generation'],
  }, null, 2) + '\n');
}

async function capture(label, targetPage = page) {
  if (options.screenshots === 'false') return;
  const relative = `docs/media/${screenshotPrefix}-${label}.png`;
  await targetPage.screenshot({ path: path.join(ROOT, relative), fullPage: false });
  report.screenshots[label] = relative;
}

async function clickGame(x, y) {
  const rectangle = await page.locator('#canvas').boundingBox();
  assert(rectangle && rectangle.width > 0 && rectangle.height > 0, 'Game canvas is visible');
  await page.mouse.click(rectangle.x + rectangle.width * x / 1920, rectangle.y + rectangle.height * y / 1080);
  await page.waitForTimeout(450);
}

async function resumeFromHome() {
  await page.locator('#home').click();
  await page.waitForFunction(() => document.body.dataset.gameState === 'home');
  assert.match(await page.locator('#play').innerText(), /Resume game/);
  assert.equal(await page.locator('#diorama canvas').count(), 0, 'Home does not restart the diorama');
  await page.locator('#play').click();
  await page.waitForFunction(() => document.body.dataset.gameState === 'playing', null, { timeout: 10000 });
}

async function startBrowser() {
  const playwright = require(options.playwright || process.env.GLOAM_PLAYWRIGHT_MODULE || 'playwright');
  if (browserName === 'chromium') {
    report.runtime = { headless: true, software_rendering_requested: 'ANGLE SwiftShader',
      executable: options.executable || playwright.chromium.executablePath() };
    return playwright.chromium.launch({ headless: true,
      ...(options.executable ? { executablePath: options.executable } : {}),
      args: ['--no-sandbox', '--enable-unsafe-swiftshader'] });
  }
  const environment = { ...process.env, MOZ_ENABLE_WAYLAND: '0', LIBGL_ALWAYS_SOFTWARE: '1', MOZ_WEBRENDER: '1' };
  if (options.xvfb) {
    let display = 196;
    while (fs.existsSync(`/tmp/.X11-unix/X${display}`) || fs.existsSync(`/tmp/.X${display}-lock`)) display++;
    environment.DISPLAY = `:${display}`;
    const executable = path.resolve(ROOT, options.xvfb);
    xvfb = spawn(executable, [environment.DISPLAY, '-screen', '0', '1600x900x24', '+extension', 'GLX',
      '+extension', 'RENDER', '-noreset', '-nolisten', 'tcp'], { stdio: 'ignore' });
    await new Promise((resolve, reject) => {
      const timer = setTimeout(resolve, 1000);
      xvfb.once('error', error => { clearTimeout(timer); reject(error); });
      xvfb.once('exit', code => { clearTimeout(timer); reject(new Error(`Xvfb exited with ${code}`)); });
    });
  }
  report.runtime = { headless: !options.xvfb, display: environment.DISPLAY || null,
    software_rendering_requested: 'Mesa software rendering',
    executable: options.executable || playwright.firefox.executablePath(),
    xvfb: options.xvfb ? path.resolve(ROOT, options.xvfb) : null };
  return playwright.firefox.launch({ headless: !options.xvfb, env: environment,
    ...(options.executable ? { executablePath: options.executable } : {}),
    firefoxUserPrefs: { 'webgl.force-enabled': true, 'webgl.disabled': false,
      'gfx.webrender.software': true, 'gfx.webrender.all': true } });
}

async function run() {
  browser = await startBrowser();
  context = await browser.newContext({ viewport, reducedMotion: 'no-preference' });
  // Attribute RAF callbacks by their served script URL. Godot's own RAF is excluded.
  await context.addInitScript(() => {
    const pending = new Map();
    const request = window.requestAnimationFrame.bind(window);
    const cancel = window.cancelAnimationFrame.bind(window);
    window.requestAnimationFrame = callback => {
      const stack = new Error().stack || '';
      const id = request(time => { pending.delete(id); callback(time); });
      pending.set(id, stack);
      return id;
    };
    window.cancelAnimationFrame = id => { pending.delete(id); cancel(id); };
    const trace = [];
    const record = entry => { trace.push({ ...entry, time: performance.now() }); if (trace.length > 400) trace.shift(); };
    for (const name of ['pointerdown', 'pointerup', 'click', 'dblclick']) {
      document.addEventListener(name, event => record({ event: name, target: event.target.id,
        button: event.target.closest?.('button')?.id, state: document.body?.dataset.gameState,
        x: event.clientX, y: event.clientY, scroll_y: scrollY }), true);
    }
    document.addEventListener('DOMContentLoaded', () => new MutationObserver(() => record({
      event: 'state', state: document.body.dataset.gameState, classes: document.body.className,
    })).observe(document.body, { attributes: true, attributeFilter: ['class', 'data-game-state'] }));
    window.__gloamSmoke = { trace, record,
      websiteFrames: () => [...pending.values()].filter(stack => /site-[A-Za-z0-9_-]+\.js/.test(stack)).length };
  });
  page = await context.newPage();
  const engineRequests = [];
  const authoringRequests = [];
  page.on('pageerror', error => report.errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') report.errors.push(message.text()); });
  page.on('request', request => {
    if (/\/game-[^/]+\.(js|wasm|pck)(?:\?|$)/.test(request.url())) engineRequests.push(request.url());
    if (request.url().includes('/api/forge/')) authoringRequests.push({ method: request.method(), path: new URL(request.url()).pathname });
  });
  page.on('requestfailed', request => report.request_failures.push({ url: request.url(), error: request.failure()?.errorText }));
  const response = await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
  assert.equal(response.status(), 200, 'Public landing returns HTTP 200');
  const buildResponse = await page.request.get(new URL('BUILD.json', url).href);
  assert.equal(buildResponse.status(), 200, 'Public BUILD is available');
  report.build = await buildResponse.json();
  assert.equal(report.build.implementation_commit, expectedCommit, 'Exact intended public release');
  assert.equal(report.build.dirty_qa_build, false, 'Public source is clean');
  report.user_agent = await page.evaluate(() => navigator.userAgent);
  report.landing_title = await page.title();
  assert.match(report.landing_title, /Gloamthread/);
  report.checks.public_build = true;
  await page.waitForFunction(() => document.body.classList.contains('diorama-ready'), null, { timeout: 30000 });
  assert.equal(engineRequests.length, 0, 'Game loader, WASM and pack wait for Play');
  report.checks.deferred_game_assets = true;
  report.renderer = await page.locator('#diorama canvas').evaluate(canvas => {
    const gl = canvas.getContext('webgl2');
    const debug = gl?.getExtension('WEBGL_debug_renderer_info');
    return debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : gl?.getParameter(gl.RENDERER);
  });
  report.website_frames_before_play = await page.evaluate(() => window.__gloamSmoke.websiteFrames());
  assert(report.website_frames_before_play > 0, 'Living diorama has a pending website frame');
  await page.evaluate(() => {
    const home = window.GloamWeb.home;
    window.GloamWeb.home = function (...arguments_) {
      window.__gloamSmoke.record({ event: 'home-call', stack: new Error().stack });
      return home.apply(this, arguments_);
    };
  });
  await page.locator('#play').click();
  progressTimer = setInterval(async () => {
    try { console.log(`[${browserName}] ${await page.locator('#status').innerText()}`); } catch { /* Page may be closing. */ }
  }, 10000);
  await page.waitForFunction(() => ['playing', 'error'].includes(document.body.dataset.gameState), null, { timeout: 180000 });
  clearInterval(progressTimer);
  assert.equal(await page.locator('body').getAttribute('data-game-state'), 'playing', await page.locator('#status').innerText());
  await page.waitForTimeout(1200);
  assert.equal(await page.locator('#diorama canvas').count(), 0, 'Website renderer is removed before Godot');
  report.website_frames_after_play = await page.evaluate(() => window.__gloamSmoke.websiteFrames());
  assert.equal(report.website_frames_after_play, 0, 'No website RAF remains alongside Godot');
  report.checks.renderer_disposed = true;
  await capture('title');
  await clickGame(400, 684);
  await page.waitForFunction(() => document.body.dataset.mode === 'story');
  await page.waitForTimeout(550);
  report.story_canvas = await page.locator('#canvas').evaluate(canvas => ({ width: canvas.width, height: canvas.height }));
  assert.equal(report.story_canvas.width / report.story_canvas.height, 960 / 360);
  for (let index = 0; index < 2; index++) {
    await page.keyboard.press('s', { delay: 90 });
    await page.waitForTimeout(180);
  }
  await page.keyboard.press('Space', { delay: 90 });
  await page.waitForFunction(() => document.body.dataset.mode === 'arena');
  await page.waitForTimeout(550);
  report.checks.story_entry_return = true;
  await clickGame(400, 530);
  await clickGame(1590, 895);
  await page.waitForTimeout(1500);
  await page.keyboard.down('f');
  await page.keyboard.down('d');
  await page.waitForTimeout(1100);
  await page.keyboard.up('d');
  await page.keyboard.up('f');
  await capture('combat');
  report.checks.solo_combat_inputs = true;
  await page.keyboard.press('Escape', { delay: 90 });
  await page.waitForTimeout(350);
  await page.locator('#home').click();
  await page.waitForFunction(() => document.body.dataset.gameState === 'home');
  const guide = page.locator('a[data-guide][href="help.html"]').first();
  assert.equal(await guide.getAttribute('target'), '_blank');
  const popupPromise = page.waitForEvent('popup');
  await guide.click();
  const popup = await popupPromise;
  await popup.waitForLoadState('networkidle');
  assert(await popup.locator('.guide-content').isVisible(), 'Generated player guide renders');
  report.guide_title = await popup.title();
  await capture('guide', popup);
  await popup.close();
  await page.locator('#play').click();
  await page.waitForFunction(() => document.body.dataset.gameState === 'playing');
  report.checks.pause_home_resume_guide = true;
  report.resume_cycles = [];
  for (let index = 0; index < cycles; index++) {
    await resumeFromHome();
    report.resume_cycles.push({ cycle: index + 1, state: await page.locator('body').getAttribute('data-game-state') });
  }
  report.checks.fast_home_resume_cycles = cycles;
  await capture('resumed');
  report.game_canvas = await page.locator('#canvas').evaluate(canvas => ({ width: canvas.width, height: canvas.height,
    rectangle: canvas.getBoundingClientRect().toJSON(), stage: canvas.parentElement.getBoundingClientRect().toJSON() }));
  assert.equal(report.game_canvas.width / report.game_canvas.height, 640 / 360);
  assert(report.game_canvas.rectangle.top >= report.game_canvas.stage.top - 1);
  assert(report.game_canvas.rectangle.bottom <= report.game_canvas.stage.bottom + 1);
  assert.equal(report.errors.length, 0, report.errors.join('\n'));
  assert.equal(report.request_failures.length, 0, JSON.stringify(report.request_failures));
  report.checks.console_and_network = true;
  report.engine_assets_requested_after_play = engineRequests.map(item => new URL(item).pathname);
  if (options.forge === 'true') {
    // End only this isolated test run through its real confirmation menu.
    await clickGame(950, 680);
    await clickGame(1100, 610);
    const configurationPromise = page.waitForResponse(item => item.url().endsWith('/api/forge/configuration'));
    await clickGame(400, 760);
    const configurationResponse = await configurationPromise;
    assert.equal(configurationResponse.status(), 200);
    const configuration = await configurationResponse.json();
    assert.equal(configuration.ok, true);
    assert.equal(configuration.authenticated, false);
    assert.equal(configuration.worker_ready, true);
    await page.waitForTimeout(650);
    await capture('forge');
    assert.equal(authoringRequests.filter(item => item.method !== 'GET').length, 0);
    assert.equal(report.errors.length, 0, report.errors.join('\n'));
    report.forge = { http_status: configurationResponse.status(), authenticated: configuration.authenticated,
      worker_ready: configuration.worker_ready, key_present: configuration.key_present,
      ui_opened_by_canvas_input: true, requests: authoringRequests, paid_requests: 0 };
  }
  report.final_title = await page.title();
  report.state_trace = await page.evaluate(() => window.__gloamSmoke.trace);
  report.passed = true;
}

run().catch(async error => {
  report.error = String(error);
  report.stack = error.stack;
  if (page && !page.isClosed()) {
    try {
      report.failure_state = await page.evaluate(() => ({ state: document.body.dataset.gameState,
        classes: document.body.className, status: document.querySelector('#status')?.innerText,
        active_element: document.activeElement?.id, play_disabled: document.querySelector('#play')?.disabled }));
      report.state_trace = await page.evaluate(() => window.__gloamSmoke?.trace);
      await capture('failure');
    } catch { /* Preserve the original failure if a crashed browser cannot capture. */ }
  }
  process.exitCode = 1;
}).finally(async () => {
  clearInterval(progressTimer);
  try { if (context) await context.close(); } finally { if (browser) await browser.close(); if (xvfb) xvfb.kill(); }
  saveReport();
  console.log(JSON.stringify({ browser: browserName, passed: report.passed,
    build: report.build?.implementation_commit, checks: report.checks, errors: report.errors, error: report.error }, null, 2));
});
