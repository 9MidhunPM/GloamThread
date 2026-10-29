/* Public website QA. Set PLAYWRIGHT_MODULE if Playwright is installed separately. */
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const base = process.env.GLOAM_QA_URL || 'https://gloamthread.midhunpm.in/';
const media = path.resolve(__dirname, '../../docs/media');
const results = [];

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--enable-unsafe-swiftshader'] });
  try {
    const context = await browser.newContext({ viewport: { width: 1536, height: 1024 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    await page.goto(base, { waitUntil: 'networkidle' });
    const build = await (await page.request.get(new URL('BUILD.json', base).href)).json();
    assert.equal(build.implementation_commit, '37f5bff1f056c7811bb84a4260c1f95ee660d03d');
    assert.equal(build.dirty_qa_build, false);
    await page.waitForFunction(() => document.body.classList.contains('diorama-ready'));
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(800);
    await page.screenshot({ path: path.join(media, 'web-portal-home-desktop.png') });
    const modeStripTop = await page.locator('.mode-strip').evaluate(node => node.getBoundingClientRect().top);
    await page.getByRole('tab', { name: 'Story', exact: true }).click();
    assert.equal(await page.locator('#scene-story').getAttribute('aria-selected'), 'true');
    await page.waitForTimeout(800);
    await page.getByRole('switch').click();
    assert.equal(await page.getByRole('switch').getAttribute('aria-checked'), 'false');
    await page.reload({ waitUntil: 'networkidle' });
    assert.equal(await page.locator('#diorama canvas').count(), 0);
    assert.equal(await page.getByRole('switch').getAttribute('aria-checked'), 'false');
    assert.equal(await page.locator('#diorama-poster').evaluate(node => node.naturalWidth), 1200);
    results.push({ name: 'desktop render, scene tab, persisted motion-off poster', passed: true, mode_strip_top: modeStripTop, viewport: { width: 1536, height: 1024 } });
    await page.goto(new URL('help.html', base).href, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    assert.equal(await page.locator('.guide-sidebar a[href="#start-playing"]').getAttribute('aria-current'), 'location');
    const widths = await page.locator('table').first().evaluate(node => ({ table: node.clientWidth, row: node.querySelector('tr').getBoundingClientRect().width }));
    assert(Math.abs(widths.table - widths.row) < 2);
    await page.screenshot({ path: path.join(media, 'web-portal-guide-desktop.png') });
    await page.locator('.guide-sidebar a[href="#controls"]').click();
    await page.waitForTimeout(700);
    assert.equal(await page.locator('.guide-sidebar a[href="#controls"]').getAttribute('aria-current'), 'location');
    results.push({ name: 'guide active aliases and full-width controls table', passed: true, widths });
    await context.close();

    const mobile = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 1 });
    const phone = await mobile.newPage();
    await phone.goto(base, { waitUntil: 'networkidle' });
    await phone.waitForFunction(() => document.body.classList.contains('diorama-ready'));
    await phone.waitForTimeout(800);
    assert.equal(await phone.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    assert.equal(await phone.locator('.drag-hint').isVisible(), false);
    await phone.screenshot({ path: path.join(media, 'web-portal-home-mobile.png'), fullPage: true });
    await phone.goto(new URL('help.html', base).href, { waitUntil: 'networkidle' });
    assert.equal(await phone.locator('.guide-mobile-contents').isVisible(), true);
    assert.equal(await phone.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    await phone.screenshot({ path: path.join(media, 'web-portal-guide-mobile.png') });
    results.push({ name: 'touch-sized homepage and guide, no overflow, accurate hint', passed: true, viewport: { width: 390, height: 844 } });
    await mobile.close();

    const reduced = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 1366, height: 768 } });
    const still = await reduced.newPage();
    await still.goto(base, { waitUntil: 'networkidle' });
    assert.equal(await still.locator('#diorama canvas').count(), 0);
    assert.equal(await still.getByRole('switch').getAttribute('aria-checked'), 'false');
    assert.equal(await still.locator('#play').isEnabled(), true);
    results.push({ name: 'OS reduced motion uses usable poster without 3D initialization', passed: true });
    await reduced.close();
    assert.deepEqual(errors, []);
    fs.writeFileSync(path.join(__dirname, 'visual-checks.json'), JSON.stringify({ recorded_at_utc: new Date().toISOString(), base, implementation_commit: build.implementation_commit, browser: browser.version(), errors, results }, null, 2) + '\n');
    console.log(`PASS ${results.length} public website/guide checks`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
