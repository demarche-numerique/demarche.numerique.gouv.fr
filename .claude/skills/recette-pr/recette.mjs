#!/usr/bin/env node
// Joue un scénario de recette contre le serveur de la PR.
//   node recette.mjs <scenario.mjs> --mode auto|guide|video [--base-url URL] [--out DIR]
// auto  : sans tête, joue actions et vérifications ; sert à mettre le scénario au point.
// guide : navigateur visible, un panneau guide l'humain qui donne un verdict par étape.
// video : enregistre le scénario joué seul, avec sous-titres, en mp4.
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync, readdirSync, renameSync, rmSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

const { values: opts, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    mode: { type: 'string', default: 'guide' },
    'base-url': { type: 'string', default: `http://localhost:${process.env.RECETTE_PORT || 3100}` },
    out: { type: 'string' },
    rythme: { type: 'string', default: '1' } // multiplicateur des pauses vidéo
  }
});
const scenarioPath = resolve(positionals[0] ?? die('usage: recette.mjs <scenario.mjs> --mode auto|guide|video'));
const scenario = (await import(pathToFileURL(scenarioPath))).default;
const mode = opts.mode;
const baseURL = opts['base-url'];
const out = resolve(opts.out ?? join(dirname(scenarioPath), `resultats-${mode}`));
const worktree = execFileSync('git', ['-C', dirname(scenarioPath), 'rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
const pause = (ms) => new Promise((r) => setTimeout(r, ms * Number(opts.rythme)));
const PASSWORD = 'this is a very complicated password !'; // db/seeds/setup.rb

function die(msg) { console.error(msg); process.exit(1); }

// Préparation des données propres au scénario (en plus des seeds), dans la base de la PR.
// Le code Ruby imprime en dernière ligne un JSON, exposé aux étapes sous `data`.
function preparer() {
  if (!scenario.preparation) return {};
  const file = join(out, 'preparation.rb');
  writeFileSync(file, scenario.preparation);
  const stdout = execFileSync('bin/rails', ['runner', file], {
    cwd: worktree,
    env: { ...process.env, DB_DATABASE: `tps_review_pr_${scenario.pr}` },
    encoding: 'utf8'
  });
  const last = stdout.trim().split('\n').pop();
  return last?.startsWith('{') ? JSON.parse(last) : {};
}

async function connecter(context) {
  if (!scenario.persona) return;
  const page = await context.newPage();
  await page.goto('/users/sign_in');
  await page.locator('#user_email').fill(scenario.persona);
  await page.locator('#user_password').fill(PASSWORD);
  await page.locator('#user_password').press('Enter');
  await page.waitForURL((url) => !url.pathname.startsWith('/users/sign_in'));
  await page.close();
}

// Le badge rack-mini-profiler encombre captures et vidéo ; ?pp=disable le coupe par cookie.
async function sansProfiler(context) {
  const page = await context.newPage();
  await page.goto('/?pp=disable').catch(() => {});
  await page.close();
}

// ---- Panneau injecté dans la page (hors <body> : Turbo remplace le body) ----
const OVERLAY = () => {
  if (window.top !== window) return;
  const css = `
    :host { all: initial; }
    .p { position: fixed; z-index: 2147483647; font: 15px/1.4 Marianne, system-ui, sans-serif; background: #161616; color: #fff; border-radius: 8px; padding: 14px 16px; box-shadow: 0 6px 24px #0007; }
    .guide { right: 16px; bottom: 16px; width: 380px; }
    .video { left: 50%; bottom: 20px; transform: translateX(-50%); width: min(900px, 90vw); text-align: center; }
    .n { color: #9a9aff; font-size: 12px; text-transform: uppercase; letter-spacing: .05em; }
    h2 { margin: 4px 0 6px; font-size: 17px; }
    .c { margin: 0 0 8px; white-space: pre-line; }
    .a { margin: 0; padding: 8px 10px; background: #1f3d2a; border-left: 4px solid #3fb96f; border-radius: 4px; }
    .a[hidden] { display: none; }
    .e { margin: 8px 0 0; padding: 8px 10px; background: #5c0a0f; border-left: 4px solid #e1000f; border-radius: 4px; }
    .b { display: flex; gap: 6px; margin-top: 10px; flex-wrap: wrap; }
    button { font: inherit; border: 0; border-radius: 4px; padding: 6px 10px; cursor: pointer; }
    .ok { background: #3fb96f; } .ko { background: #e1000f; color: #fff; } .do { background: #fff; }
    textarea { width: 100%; box-sizing: border-box; margin-top: 8px; min-height: 60px; font: inherit; }
    .min { position: absolute; top: 6px; right: 8px; background: none; color: #aaa; padding: 2px 6px; }
    .reduit .c, .reduit .a, .reduit .b, .reduit textarea { display: none; }`;
  const render = (s) => {
    let host = document.getElementById('recette-host');
    if (!s) return host?.remove();
    if (!host) {
      host = document.createElement('recette-panneau');
      host.id = 'recette-host';
      host.attachShadow({ mode: 'open' });
      document.documentElement.appendChild(host);
    }
    host.style.display = s.cache ? 'none' : '';
    const e = (t) => String(t ?? '').replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' })[c]);
    const guide = s.mode === 'guide';
    host.shadowRoot.innerHTML = `<style>${css}</style>
      <div class="p ${guide ? 'guide' : 'video'} ${s.reduit ? 'reduit' : ''}" role="dialog" aria-label="Recette">
        ${guide ? '<button class="min" data-ev="reduire" title="Réduire">▁</button>' : ''}
        <div class="n">${e(s.entete)}</div>
        <h2>${e(s.titre)}</h2>
        ${s.consigne ? `<p class="c">${e(s.consigne)}</p>` : ''}
        ${s.attendu ? `<p class="a" ${s.montrerAttendu ? '' : 'hidden'}>✓ Attendu : ${e(s.attendu)}</p>` : ''}
        ${s.echec ? `<p class="e">✗ Échec : ${e(s.echec)}</p>` : ''}
        ${guide && s.boutons ? `<div class="b">
          ${s.action && !s.fait ? '<button class="do" data-ev="faire" title="Seulement si vous ne l’avez pas déjà fait à la main">▶ Le faire pour moi</button>' : ''}
          <button class="ok" data-ev="ok">✅ Conforme</button>
          <button class="ko" data-ev="ko">❌ Pas conforme</button>
        </div>
        <textarea hidden placeholder="Ce que vous voyez à la place (Entrée pour valider)"></textarea>` : ''}
        ${guide && s.fin ? '<div class="b"><button class="ok" data-ev="fermer">Fermer la recette</button></div>' : ''}
      </div>`;
    const root = host.shadowRoot;
    root.querySelectorAll('[data-ev]').forEach((b) => b.addEventListener('click', () => {
      if (b.dataset.ev === 'ko') {
        const t = root.querySelector('textarea');
        t.hidden = false; t.focus();
        t.addEventListener('keydown', (ev) => {
          if (ev.key === 'Enter' && !ev.shiftKey) { ev.preventDefault(); window.__recetteEvent('ko', t.value); }
        });
      } else window.__recetteEvent(b.dataset.ev);
    }));
  };
  window.__recetteRender = render;
  const boot = () => window.__recetteState().then(render);
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
};

// Surlignage en style inline : une feuille ajoutée au <head> ne survit pas aux visites Turbo.
const SURLIGNER = (el) => {
  el.setAttribute('data-recette-cible', '');
  el.style.setProperty('outline', '4px solid #ff9940', 'important');
  el.style.setProperty('outline-offset', '3px', 'important');
  el.style.setProperty('border-radius', '4px');
};
const eteindre = (page) => page.locator('[data-recette-cible]').evaluateAll((els) => els.forEach((el) => {
  el.removeAttribute('data-recette-cible');
  ['outline', 'outline-offset', 'border-radius'].forEach((p) => el.style.removeProperty(p));
})).catch(() => {});

async function main() {
  // Garde : on ne vide que ce qui ressemble à une sortie de recette.
  if (existsSync(out) && readdirSync(out).length && !existsSync(join(out, 'resultats.json')) && !existsSync(join(out, 'preparation.rb'))) {
    die(`${out} n'est pas un dossier de résultats de recette : choisissez un autre --out`);
  }
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  const data = preparer();

  // RECETTE_CDP_PORT : permet de piloter le mode guide depuis un autre process (test du runner).
  const browser = await chromium.launch({
    headless: mode !== 'guide' || !!process.env.RECETTE_HEADLESS,
    slowMo: mode === 'guide' ? 100 : 0,
    args: process.env.RECETTE_CDP_PORT ? [`--remote-debugging-port=${process.env.RECETTE_CDP_PORT}`] : []
  });
  const viewport = { width: 1280, height: 800 };
  const auth = await browser.newContext({ baseURL, viewport });
  await connecter(auth);
  await sansProfiler(auth);
  const storageState = await auth.storageState();
  await auth.close();

  const context = await browser.newContext({
    baseURL, viewport, storageState, locale: 'fr-FR',
    ...(mode === 'video' ? { recordVideo: { dir: out, size: viewport } } : {})
  });

  let state = null;
  let attente = null;
  await context.exposeBinding('__recetteState', () => state);
  await context.exposeBinding('__recetteEvent', (_src, type, payload) => attente?.({ type, payload }));
  if (mode !== 'auto') await context.addInitScript(OVERLAY);

  const page = await context.newPage();
  if (process.env.RECETTE_DEBUG) {
    page.on('console', (m) => console.error(`[page] ${m.text()}`));
    page.on('pageerror', (e) => console.error(`[page error] ${e.message}`));
  }
  // Borné aussi en mode guide : une action bloquée rendrait le panneau muet.
  page.setDefaultTimeout(10_000);
  const afficher = async (s) => {
    state = s;
    await page.evaluate((st) => window.__recetteRender?.(st), s).catch(() => {});
  };
  const evenement = () => new Promise((r) => { attente = r; });
  let ferme = false; // l'humain a fermé la fenêtre : on garde ce qui a été jugé
  page.on('close', () => { ferme = true; attente?.({ type: 'fermer' }); });

  const depart = typeof scenario.depart === 'function' ? scenario.depart(data) : scenario.depart;
  await page.goto(depart);

  const total = scenario.etapes.length;
  const resultats = [];
  function ecrireRapport() {
    writeFileSync(join(out, 'resultats.json'), JSON.stringify({ pr: scenario.pr, titre: scenario.titre, mode, resultats }, null, 2));
    // Un ✅ ne sort que d'un humain ; une vérification machine est un 🤖.
    const icone = { conforme: '✅', vérifié: '🤖', joué: '▶️', 'non conforme': '❌', échec: '❌' };
    const cell = (t) => String(t ?? '').replace(/\|/g, '\\|').replace(/\n/g, ' ');
    writeFileSync(join(out, 'rapport.md'), [
      mode === 'guide' ? `### Recette manuelle — ${scenario.titre}` : `### Vérification automatique — ${scenario.titre}`, '',
      `Persona : \`${scenario.persona ?? 'anonyme'}\` · ` + (mode === 'guide'
        ? `${resultats.filter((r) => r.verdict === 'conforme').length}/${total} jugées conformes par un humain`
        : `${resultats.filter((r) => r.verdict === 'vérifié').length}/${total} vérifiées par le script (aucun jugement humain)`), '',
      '| # | Étape | Attendu | Verdict |', '|---|---|---|---|',
      ...resultats.map((r) => `| ${r.etape} | ${cell(r.titre)} | ${cell(r.attendu)} | ${icone[r.verdict] ?? ''} ${cell(r.commentaire ?? r.erreur ?? '')} |`),
      ...(resultats.length < total ? [`| | ${total - resultats.length} étape(s) non jouée(s) | | |`] : [])
    ].join('\n') + '\n');
  }

  if (mode === 'video') {
    await afficher({ mode, entete: `PR #${scenario.pr}`, titre: scenario.titre, consigne: scenario.contexte });
    await pause(3500);
  }

  for (const [i, etape] of scenario.etapes.entries()) {
    const ctx = { page, data };
    const base = { mode, entete: `Étape ${i + 1}/${total}`, titre: etape.titre, consigne: etape.consigne, attendu: etape.attendu, action: !!etape.action };
    const cible = etape.cible?.(ctx);
    await eteindre(page);
    if (cible) {
      // Timeout court : une cible absente ne doit pas bloquer le guidage.
      await cible.first().scrollIntoViewIfNeeded({ timeout: 3000 }).catch(() => {});
      await cible.first().evaluate(SURLIGNER, null, { timeout: 3000 }).catch(() => {});
    }
    const resultat = { etape: i + 1, titre: etape.titre, attendu: etape.attendu };

    if (mode === 'guide') {
      // Le panneau se redessine après chaque navigation via __recetteState.
      let reduit = false;
      await afficher({ ...base, boutons: true, montrerAttendu: true, reduit });
      for (;;) {
        const ev = await evenement();
        if (ev.type === 'reduire') { reduit = !reduit; await afficher({ ...state, reduit }); continue; }
        if (ev.type === 'fermer') break;
        if (ev.type === 'faire') {
          await afficher({ ...state, fait: true, consigne: '⏳ En cours…' });
          try { await etape.action(ctx); await afficher({ ...state, consigne: '✓ Fait. Vérifiez l’attendu ci-dessous.' }); }
          catch (err) { await afficher({ ...state, consigne: `⚠ Action impossible : ${err.message.split('\n')[0]}. Faites-la à la main.` }); }
          continue;
        }
        resultat.verdict = ev.type === 'ok' ? 'conforme' : 'non conforme';
        if (ev.payload) resultat.commentaire = ev.payload;
        break;
      }
      if (ferme || !resultat.verdict) break;
    } else {
      if (mode === 'video') { await afficher({ ...base }); await pause(2200); }
      try {
        await etape.action?.(ctx);
        await etape.verifier?.(ctx);
        resultat.verdict = etape.verifier ? 'vérifié' : 'joué';
        // La vidéo n'affiche l'attendu qu'une fois vérifié : elle ne doit rien affirmer de faux.
        if (mode === 'video') await afficher({ ...base, montrerAttendu: true });
      } catch (err) {
        resultat.verdict = 'échec';
        resultat.erreur = err.message.split('\n')[0];
        if (mode === 'video') await afficher({ ...base, echec: resultat.erreur });
      }
      if (mode === 'video') await pause(2800);
    }

    await afficher({ ...state, cache: true });
    await page.screenshot({ path: join(out, `etape-${String(i + 1).padStart(2, '0')}.png`) });
    await afficher({ ...state, cache: false });
    resultats.push(resultat);
    console.log(`${resultat.verdict === 'échec' || resultat.verdict === 'non conforme' ? '✗' : '✓'} ${i + 1}. ${etape.titre} — ${resultat.verdict}${resultat.erreur ? ` : ${resultat.erreur}` : ''}${resultat.commentaire ? ` : ${resultat.commentaire}` : ''}`);
    ecrireRapport();
    if (resultat.verdict === 'échec') break;
  }

  if (mode === 'guide' && !ferme) {
    const ko = resultats.filter((r) => r.verdict === 'non conforme');
    await eteindre(page);
    await afficher({
      mode, fin: true, entete: 'Recette terminée',
      titre: `${resultats.length - ko.length}/${total} conformes`,
      consigne: [...ko.map((r) => `❌ ${r.etape}. ${r.titre}${r.commentaire ? ` — ${r.commentaire}` : ''}`),
        `Rapport : ${join(out, 'rapport.md')}`].join('\n')
    });
    await evenement();
  }

  if (mode === 'video') {
    const echec = resultats.find((r) => r.verdict === 'échec');
    await afficher({ mode, entete: `PR #${scenario.pr}`, titre: echec ? `✗ Recette en échec à l'étape ${echec.etape}` : 'Fin de la recette', echec: echec?.erreur });
    await pause(1500);
  }
  if (!ferme) await eteindre(page);
  await context.close();
  await browser.close();

  ecrireRapport();
  if (mode === 'video') {
    const webm = readdirSync(out).find((f) => f.endsWith('.webm'));
    const mp4 = join(out, `recette-pr-${scenario.pr}.mp4`);
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', join(out, webm), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '28', '-movflags', '+faststart', mp4]);
    renameSync(join(out, webm), join(out, `recette-pr-${scenario.pr}.webm`));
    console.log(`vidéo : ${mp4}`);
  }
  console.log(`résultats : ${join(out, 'resultats.json')}`);
  process.exitCode = resultats.some((r) => ['échec', 'non conforme'].includes(r.verdict)) || resultats.length < total ? 1 : 0;
}

await main();
