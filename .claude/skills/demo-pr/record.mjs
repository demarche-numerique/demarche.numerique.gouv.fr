// Records a narrated demo video from a scenario file.
//
//   node <abs path>/.claude/skills/demo-pr/record.mjs <scenario.mjs> <out_dir> [--explore]
//
// --explore only logs in, opens `start` and saves a full-page screenshot.
// Env: DEMO_BASE_URL (default http://localhost:3001), DEMO_VOICE (`say -v`, default system voice).
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [scenarioPath, outArg] = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const explore = process.argv.includes('--explore');
if (!scenarioPath || !outArg) {
  console.error('usage: node record.mjs <scenario.mjs> <out_dir> [--explore]');
  process.exit(1);
}

const OUT = resolve(outArg);
const BASE = process.env.DEMO_BASE_URL || 'http://localhost:3001';
const VIEWPORT = { width: 1280, height: 800 };
const { default: scenario } = await import(pathToFileURL(resolve(scenarioPath)));
mkdirSync(OUT, { recursive: true });

const ffprobeDuration = (file) =>
  parseFloat(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file]).toString());

// Narration first: each scene lasts at least as long as its sentence
let segments = [];
if (!explore) {
  rmSync(`${OUT}/audio`, { recursive: true, force: true });
  rmSync(`${OUT}/frames`, { recursive: true, force: true });
  mkdirSync(`${OUT}/audio`);
  mkdirSync(`${OUT}/frames`);
  segments = scenario.scenes.map(({ say }, i) => {
    if (!say?.trim()) throw new Error(`scene ${i}: empty "say"`);
    const file = `${OUT}/audio/seg${i}.aiff`;
    const voice = process.env.DEMO_VOICE ? ['-v', process.env.DEMO_VOICE] : [];
    execFileSync('say', [...voice, '-o', file, say]);
    return { file, duration: ffprobeDuration(file) };
  });
}

const browser = await chromium.launch();

// Log in outside the recording, so the video opens on the demo page. No `login`: anonymous demo.
let storageState;
if (scenario.login) {
  const loginContext = await browser.newContext();
  const loginPage = await loginContext.newPage();
  await loginPage.goto(`${BASE}/users/sign_in`);
  await loginPage.fill('#user_email', scenario.login.email);
  await loginPage.fill('#user_password', scenario.login.password);
  await loginPage.locator('#user_password').press('Enter');
  await loginPage.waitForLoadState('networkidle');
  if (new URL(loginPage.url()).pathname.startsWith('/users/sign_in')) {
    await browser.close();
    throw new Error(`login failed for ${scenario.login.email}: wrong password, or account missing from the dev database`);
  }
  storageState = await loginContext.storageState();
  await loginContext.close();
}

const context = await browser.newContext({
  storageState,
  viewport: VIEWPORT,
  ...(explore ? {} : { recordVideo: { dir: `${OUT}/video`, size: VIEWPORT } }),
});
// Hide the rack-mini-profiler badge of the dev environment
await context.addInitScript(() => {
  document.addEventListener('DOMContentLoaded', () => {
    const style = document.createElement('style');
    style.textContent = '.profiler-results { display: none !important; }';
    document.head.append(style);
  });
});
const page = await context.newPage();
const t0 = Date.now();

await page.goto(`${BASE}${scenario.start}`, { timeout: 120000 });
await page.waitForLoadState('networkidle');

if (explore) {
  await page.screenshot({ path: `${OUT}/explore.png`, fullPage: true });
  await browser.close();
  console.log(`${OUT}/explore.png`);
  process.exit(0);
}

const pause = (ms) => page.waitForTimeout(ms);
// Scrolls to the element and frames it in red for `ms`
async function focus(locator, ms = 1500) {
  await locator.evaluate((el) => el.scrollIntoView({ behavior: 'smooth', block: 'center' }));
  await pause(700);
  await locator.evaluate((el) => { el.style.outline = '3px solid #e1000f'; el.style.outlineOffset = '4px'; });
  await pause(ms);
  await locator.evaluate((el) => { el.style.outline = ''; el.style.outlineOffset = ''; }).catch(() => {});
}
// Waits for a transient message (flash, "Formulaire enregistré"…) without failing the demo
const waitText = (text, timeout = 10000) => page.getByText(text).first().waitFor({ timeout }).catch(() => {});
const helpers = { page, pause, focus, waitText };

const timeline = [];
for (const [i, { run }] of scenario.scenes.entries()) {
  const start = Date.now() - t0;
  await run(helpers);
  const remaining = segments[i].duration * 1000 - (Date.now() - t0 - start);
  await pause(Math.max(remaining, 0) + 600);
  timeline.push({ ...segments[i], start, end: Date.now() - t0 });
}

const video = page.video();
await context.close();
await browser.close();
const webm = await video.path();

// Cut the page load before the first scene, then lay each sentence at its timestamp
const offset = timeline[0].start;
const out = `${OUT}/demo.mp4`;
const inputs = timeline.flatMap((s) => ['-i', s.file]);
const delays = timeline.map((s, i) => `[${i + 1}]adelay=delays=${s.start - offset}:all=1[a${i}]`).join(';');
const mix = `${timeline.map((_, i) => `[a${i}]`).join('')}amix=inputs=${timeline.length}:normalize=0[a]`;
execFileSync('ffmpeg', ['-y', '-v', 'error', '-ss', String(offset / 1000), '-i', webm, ...inputs,
  '-filter_complex', `${delays};${mix}`,
  '-map', '0:v', '-map', '[a]', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-c:a', 'aac', '-b:a', '160k', out]);

// One frame at the end of each scene, tiled into a contact sheet to check the result
timeline.forEach((s, i) => execFileSync('ffmpeg', ['-y', '-v', 'error', '-ss', String((s.end - offset) / 1000 - 0.5),
  '-i', out, '-frames:v', '1', '-vf', 'scale=640:-1', `${OUT}/frames/f${String(i).padStart(2, '0')}.png`]));
execFileSync('ffmpeg', ['-y', '-v', 'error', '-pattern_type', 'glob', '-i', `${OUT}/frames/f*.png`,
  '-filter_complex', `tile=2x${Math.ceil(timeline.length / 2)}`, '-frames:v', '1', `${OUT}/frames/sheet.png`]);

console.log(`${out} (${ffprobeDuration(out).toFixed(0)} s)\n${OUT}/frames/sheet.png`);
