#!/usr/bin/env node
/**
 * Browser smoke: homepage renders, download CTAs point at a .dmg, theme toggles.
 * Usage: node scripts/website-browser-test.mjs http://127.0.0.1:8765
 */
import { chromium } from 'playwright';

const base = process.argv[2] || 'http://127.0.0.1:8765';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
const errors = [];

page.on('pageerror', (e) => errors.push(String(e)));

try {
  await page.goto(base + '/', { waitUntil: 'networkidle', timeout: 30000 });

  const title = await page.title();
  if (!/CleanMac/i.test(title)) throw new Error('bad title: ' + title);

  const brand = await page.locator('h1.brand-hero').textContent();
  if (!brand || !brand.includes('CleanMac')) throw new Error('missing brand hero');

  // Wait for download.js to resolve (or keep fallback).
  await page.waitForTimeout(1500);

  const hrefs = await page.$$eval('[data-dmg]', (els) =>
    els.map((a) => a.getAttribute('href'))
  );
  if (!hrefs.length) throw new Error('no [data-dmg] buttons');
  for (const h of hrefs) {
    if (!h || !/\.dmg(\?|$)/i.test(h)) {
      throw new Error('download href is not a dmg: ' + h);
    }
    if (/\/releases\/latest\/?$/i.test(h)) {
      throw new Error('download still points at release page: ' + h);
    }
  }

  // Theme toggle should flip data-theme.
  const before = await page.getAttribute('html', 'data-theme');
  await page.click('#theme-toggle');
  await page.waitForTimeout(200);
  const after = await page.getAttribute('html', 'data-theme');
  if (before === after) throw new Error('theme toggle did not change theme');

  // Features / download anchors exist.
  await page.click('a[href="#download"]');
  await page.waitForSelector('#download .btn[data-dmg]', { timeout: 5000 });

  if (errors.length) throw new Error('page errors: ' + errors.join('; '));

  console.log('browser smoke passed');
  console.log('  dmg hrefs:', hrefs.join(', '));
  console.log('  theme:', before, '→', after);
} finally {
  await browser.close();
}
