#!/usr/bin/env node
// Joue un scénario de recette contre le serveur de la PR.
//   node recette.mjs <scenario.mjs> --mode auto|guide|video|captures [--base-url URL] [--out DIR] [--rythme N] [--muet] [--voix NOM]
// auto     : sans tête, joue actions et vérifications ; sert à mettre le scénario au point.
// guide    : navigateur visible, un panneau guide l'humain qui donne un verdict par étape.
// video    : enregistre le scénario joué seul, avec le panneau et une voix off (macOS `say`), en mp4.
// captures : sans tête, capture le panneau du mode guide à chaque étape (pour la description d'une PR).
// sonde    : se connecte, ouvre --page (sinon le départ) et affiche l'arbre d'accessibilité,
//            pour écrire les locators d'après le DOM réel plutôt qu'en devinant.
import { chromium } from 'playwright';
import * as outils from './outils.mjs';
import { execFileSync, spawnSync } from 'node:child_process';
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
    rythme: { type: 'string', default: '1' }, // multiplicateur des pauses vidéo
    muet: { type: 'boolean', default: false }, // vidéo sans voix off
    enregistrer: { type: 'boolean', default: false }, // guide : filme la recette du relecteur, en mp4
    juge: { type: 'string', default: 'humain' }, // guide : « agent » quand un agent joue le relecteur
    voix: { type: 'string' }, // voix `say -v` ; par défaut la première voix française installée
    page: { type: 'string' }, // sonde : chemin à ouvrir
    clic: { type: 'string', multiple: true } // sonde : boutons ou liens à cliquer avant d'afficher l'arbre
  }
});
const scenarioPath = resolve(positionals[0] ?? die('usage: recette.mjs <scenario.mjs> --mode auto|guide|video|captures'));
const scenario = (await import(pathToFileURL(scenarioPath))).default;
const mode = opts.mode;
if (!['auto', 'guide', 'video', 'captures', 'sonde'].includes(mode)) die(`mode inconnu : ${mode}`);
const baseURL = opts['base-url'];
// Le mode vidéo filme le script ; le mode guide peut filmer le relecteur, pour montrer la recette.
const filmer = mode === 'video' || (mode === 'guide' && opts.enregistrer);
const out = resolve(opts.out ?? join(dirname(scenarioPath), `resultats-${mode}`));
const worktree = execFileSync('git', ['-C', dirname(scenarioPath), 'rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
const pause = (ms) => new Promise((r) => setTimeout(r, ms * Number(opts.rythme)));
const PASSWORD = 'this is a very complicated password !'; // db/seeds/setup.rb

function die(msg) { console.error(msg); process.exit(1); }

// ---- Voix off (repris de /demo-pr, #14665) : macOS seulement, sinon vidéo muette ----
function choisirVoix() {
  if (!filmer || opts.muet) return null;
  const liste = spawnSync('say', ['-v', '?'], { encoding: 'utf8' });
  if (liste.error || liste.status !== 0) {
    console.warn('`say` indisponible : vidéo sans voix off (sous-titres seuls).');
    return null;
  }
  if (opts.voix) return opts.voix;
  // Une voix compacte (installée d'office) sonne robotique : on prend la meilleure qualité
  // installée, Premium puis Améliorée, et à qualité égale Aurélie d'abord (jugée la plus naturelle).
  const francaises = liste.stdout.split('\n').map((l) => l.match(/^(.+?)\s+fr_FR\s/)?.[1]).filter(Boolean);
  const qualite = (v) => (/Premium/i.test(v) ? 2 : /Enhanced|Améliorée/i.test(v) ? 1 : 0);
  const prenom = (v) => ['Aurélie', 'Audrey', 'Marie', 'Thomas'].findIndex((p) => v.startsWith(p));
  const rang = (v) => qualite(v) * 10 - (prenom(v) === -1 ? 5 : prenom(v));
  const voix = [...francaises].sort((a, b) => rang(b) - rang(a))[0];
  if (!voix) console.warn('Aucune voix fr_FR installée : voix système par défaut.');
  else if (!qualite(voix)) console.warn(`Voix compacte (${voix}), au rendu robotique : installez une voix française Améliorée ou Premium (Réglages Système > Accessibilité > Lire et énoncer > ⓘ à côté de « Voix système »).`);
  return voix ?? '';
}

const dureeAudio = (file) =>
  parseFloat(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file], { encoding: 'utf8' }));

// Synthétise chaque phrase une seule fois (avant l'enregistrement, pour ne pas filmer d'attente).
function synthetiseur(voix) {
  const cache = new Map();
  return (texte) => {
    if (voix === null || !texte?.trim()) return null;
    if (!cache.has(texte)) {
      const n = String(cache.size).padStart(3, '0');
      const txt = join(out, 'voix', `${n}.txt`);
      const file = join(out, 'voix', `${n}.aiff`);
      mkdirSync(dirname(file), { recursive: true });
      writeFileSync(txt, texte);
      execFileSync('say', [...(voix ? ['-v', voix] : []), '-f', txt, '-o', file]);
      cache.set(texte, { file, duree: dureeAudio(file) * 1000 });
    }
    return cache.get(texte);
  };
}

// Préparation des données propres au scénario (en plus des seeds), dans la base de la PR.
// Le code Ruby imprime en dernière ligne un JSON, exposé aux étapes sous `data`.
function preparer() {
  if (!scenario.preparation) return {};
  const file = join(out, 'preparation.rb');
  writeFileSync(file, scenario.preparation);
  let stdout;
  try {
    stdout = execFileSync('bin/rails', ['runner', file], {
      cwd: worktree,
      env: { ...process.env, DB_DATABASE: `tps_review_pr_${scenario.pr}` },
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe']
    });
  } catch (err) {
    // Seulement l'erreur Ruby et les lignes de la préparation, pas la pile des gems.
    const utiles = String(err.stderr).split('\n').filter((l) => l.trim() && !/\/gems\/|bin\/rails|Skylight|skylight/.test(l));
    die(`✗ préparation en échec (${file}) :\n${utiles.slice(0, 8).join('\n')}`);
  }
  const last = stdout.trim().split('\n').pop();
  return last?.startsWith('{') ? JSON.parse(last) : {};
}

// `connexion` remplace le formulaire usager pour les personas qui se connectent autrement
// (super admin du manager, OTP…) ; elle reçoit `data`, issue de la préparation.
async function connecter(context, data) {
  if (!scenario.persona && !scenario.connexion) return;
  const page = await context.newPage();
  if (scenario.connexion) {
    await scenario.connexion({ page, data, outils });
    await page.close();
    return;
  }
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
    .guide.gauche { right: auto; left: 16px; }
    /* Transparent aux clics, sauf ses commandes : une action enchaînée sur plusieurs pages
       ne doit pas buter sur le panneau (Playwright refuse un clic sur un élément recouvert). */
    .p { pointer-events: none; } button, textarea { pointer-events: auto; }
    .s { margin: 10px 0 0; font-size: 13px; color: #cfcfff; }
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
      <div class="p guide ${s.cote === 'gauche' ? 'gauche' : ''} ${s.reduit ? 'reduit' : ''}" role="dialog" aria-label="Recette">
        ${guide ? '<button class="min" data-ev="reduire" title="Réduire">▁</button>' : ''}
        <div class="n">${e(s.entete)}</div>
        <h2>${e(s.titre)}</h2>
        ${s.consigne ? `<p class="c">${e(s.consigne)}</p>` : ''}
        ${s.attendu ? `<p class="a" ${s.montrerAttendu ? '' : 'hidden'}>✓ Attendu : ${e(s.attendu)}</p>` : ''}
        ${s.echec ? `<p class="e">✗ Échec : ${e(s.echec)}</p>` : ''}
        ${s.statut ? `<p class="s">${e(s.statut)}</p>` : ''}
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

// En bas de page, la cible ne peut pas être centrée : le panneau passe du côté opposé.
// Après l'action, on se règle sur la `zone` à juger si l'étape en a une, sinon sur la cible ;
// si elle a disparu (changement de page), le panneau revient à droite.
const aJuger = (etape, apres) => (apres && etape.zone) || etape.cible;
async function placer(etat, etape, ctx, apres = false) {
  const box = await aJuger(etape, apres)?.(ctx)?.first().boundingBox({ timeout: 1000 }).catch(() => null);
  etat.cote = box && box.x + box.width / 2 > 640 ? 'gauche' : 'droite';
}

// Amène à l'écran ce qu'on juge : la `zone` après l'action, sinon la cible.
const centrer = (etape, ctx, apres) => aJuger(etape, apres)?.(ctx)?.first()
  .evaluate((el) => el.scrollIntoView({ block: 'center', behavior: 'instant' }), null, { timeout: 1000 }).catch(() => {});

async function main() {
  // Garde : on ne vide que ce qui ressemble à une sortie de recette.
  if (existsSync(out) && readdirSync(out).length && !existsSync(join(out, 'resultats.json')) && !existsSync(join(out, 'preparation.rb'))) {
    die(`${out} n'est pas un dossier de résultats de recette : choisissez un autre --out`);
  }
  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });
  const data = preparer();

  // Toutes les phrases sont synthétisées d'avance : la vidéo ne filme pas d'attente.
  const voix = choisirVoix();
  const synthetiser = synthetiseur(voix);
  const finOk = 'Fin de la recette.';
  // Voix du mode guide filmé : elle explique le panneau d'aide à la revue, puis ce que chaque
  // critère cherche à valider et le verdict du relecteur.
  const dire = {
    intro: 'Voici la recette guidée, vue par le relecteur. Le panneau d’aide lui donne, pour chaque critère d’acceptation, la consigne à suivre et le résultat attendu, et entoure en orange l’élément à manipuler. Il peut faire l’action lui-même, ou cliquer « Le faire pour moi ». Puis il compare l’écran à l’attendu, et tranche : conforme, ou pas conforme avec un commentaire.',
    etape: (i, e) => `Critère ${i + 1} : ${e.titre}. ${e.narration ?? e.consigne}`,
    valider: (e) => `Ce qu’on valide : ${e.attendu}`,
    ok: 'Le relecteur juge le critère conforme.',
    ko: (commentaire) => `Pas conforme. Le relecteur explique pourquoi : ${commentaire}`,
    fin: (n, t) => `La recette est terminée : ${n} critères sur ${t} sont conformes. Le rapport liste les verdicts et les commentaires, prêt à coller dans la PR.`
  };
  if (voix !== null && mode === 'video') {
    [scenario.narration ?? scenario.contexte, finOk,
      ...scenario.etapes.flatMap((e) => [e.narration ?? e.consigne, e.attendu])].forEach(synthetiser);
  }
  if (voix !== null && mode === 'guide') {
    [dire.intro, dire.ok, ...scenario.etapes.flatMap((e, i) => [dire.etape(i, e), dire.valider(e)])].forEach(synthetiser);
  }

  // RECETTE_CDP_PORT : permet de piloter le mode guide depuis un autre process (test du runner).
  const browser = await chromium.launch({
    headless: mode !== 'guide' || !!process.env.RECETTE_HEADLESS,
    slowMo: mode === 'guide' ? 100 : 0,
    args: process.env.RECETTE_CDP_PORT ? [`--remote-debugging-port=${process.env.RECETTE_CDP_PORT}`] : []
  });
  const viewport = { width: 1280, height: 800 };
  const auth = await browser.newContext({ baseURL, viewport });
  await connecter(auth, data);
  await sansProfiler(auth);
  const storageState = await auth.storageState();
  await auth.close();

  const context = await browser.newContext({
    baseURL, viewport, storageState, locale: 'fr-FR',
    ...(filmer ? { recordVideo: { dir: out, size: viewport } } : {})
  });

  let state = null;
  let attente = null;
  await context.exposeBinding('__recetteState', () => state);
  await context.exposeBinding('__recetteEvent', (_src, type, payload) => attente?.({ type, payload }));
  if (mode !== 'auto') await context.addInitScript(OVERLAY);
  // Filmé, Playwright n'a ni pointeur ni clic visibles : un faux curseur suit la souris et un halo
  // marque chaque clic, panneau compris (les événements du shadow DOM remontent au document).
  if (filmer) await context.addInitScript(() => {
    const poser = () => {
      const css = document.createElement('style');
      css.textContent = `
        #recette-curseur { position: fixed; z-index: 2147483647; width: 26px; height: 26px; margin: -13px 0 0 -13px; border-radius: 50%;
          background: #ffffffcc; border: 2px solid #161616; box-shadow: 0 1px 4px #0006; pointer-events: none; transition: left .12s, top .12s; }
        .recette-clic { position: fixed; z-index: 2147483646; width: 16px; height: 16px; margin: -8px 0 0 -8px; border-radius: 50%;
          border: 3px solid #ff9940; pointer-events: none; animation: recette-clic .8s ease-out forwards; }
        @keyframes recette-clic { to { transform: scale(3.5); opacity: 0; } }`;
      document.head.append(css);
      const curseur = document.createElement('div');
      curseur.id = 'recette-curseur';
      document.documentElement.append(curseur);
      addEventListener('mousemove', (e) => { curseur.style.left = `${e.clientX}px`; curseur.style.top = `${e.clientY}px`; }, true);
      addEventListener('mousedown', (e) => {
        const halo = document.createElement('div');
        halo.className = 'recette-clic';
        halo.style.left = `${e.clientX}px`; halo.style.top = `${e.clientY}px`;
        document.documentElement.append(halo);
        setTimeout(() => halo.remove(), 900);
      }, true);
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', poser); else poser();
  });
  // Le cookie ?pp=disable ne survit pas à un clearCookies (changement de compte dans une étape) :
  // on masque aussi le badge rack-mini-profiler par CSS, comme /demo-pr.
  await context.addInitScript(() => document.addEventListener('DOMContentLoaded', () => {
    const style = document.createElement('style');
    style.textContent = '.profiler-results { display: none !important; }';
    document.head.append(style);
  }));

  const page = await context.newPage();
  // La vidéo démarre avec la page : les phrases sont posées sur cette horloge.
  const t0 = Date.now();
  const pistes = [];
  const parler = (texte) => {
    const segment = synthetiser(texte);
    if (!segment) return 0;
    pistes.push({ file: segment.file, debut: Date.now() - t0 });
    return segment.duree;
  };
  // Mode guide filmé : la phrase en cours finit à `voixJusqua`, publié dans l'état du panneau
  // pour qu'un relecteur de démonstration attende la fin avant d'agir.
  let voixJusqua = 0;
  const direGuide = (texte) => { voixJusqua = Math.max(voixJusqua, Date.now()) + parler(texte); return voixJusqua; };
  const finirPhrase = () => new Promise((r) => setTimeout(r, Math.max(0, voixJusqua + 300 - Date.now())));
  // Une scène dure au moins `min` (× rythme) et au moins le temps de sa phrase.
  const tenir = (depuis, min, voixMs) =>
    new Promise((r) => setTimeout(r, Math.max(min * Number(opts.rythme), voixMs ? voixMs + 400 : 0) - (Date.now() - depuis)));
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

  if (mode === 'sonde') {
    if (opts.page) await page.goto(typeof opts.page === 'string' ? opts.page.replace(/\{(\w+)\}/g, (_, k) => data[k]) : depart);
    await page.waitForLoadState('networkidle');
    for (const nom of opts.clic ?? []) {
      await page.getByRole('button', { name: nom }).or(page.getByRole('link', { name: nom })).first().click();
      await page.waitForLoadState('networkidle');
    }
    console.log(`${page.url()}\n${await page.locator('body').ariaSnapshot()}`);
    await context.close();
    await browser.close();
    return;
  }

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
        ? `${resultats.filter((r) => r.verdict === 'conforme').length}/${total} jugées conformes par ${opts.juge === 'agent' ? 'un agent qui joue le relecteur (aucun verdict humain)' : 'un humain'}`
        : `${resultats.filter((r) => r.verdict === 'vérifié').length}/${total} vérifiées par le script (aucun jugement humain)`), '',
      '| # | Étape | Attendu | Verdict |', '|---|---|---|---|',
      ...resultats.map((r) => `| ${r.etape} | ${cell(r.titre)} | ${cell(r.attendu)} | ${icone[r.verdict] ?? ''} ${cell(r.commentaire ?? r.erreur ?? '')} |`),
      ...(resultats.length < total ? [`| | ${total - resultats.length} étape(s) non jouée(s) | | |`] : [])
    ].join('\n') + '\n');
  }

  if (mode === 'video') {
    await afficher({ mode, entete: `PR #${scenario.pr}`, titre: scenario.titre, consigne: scenario.contexte });
    const debut = Date.now();
    await tenir(debut, 3500, parler(scenario.narration ?? scenario.contexte));
  }

  for (const [i, etape] of scenario.etapes.entries()) {
    const ctx = { page, data, outils };
    const base = { mode, entete: `Étape ${i + 1}/${total}`, titre: etape.titre, consigne: etape.consigne, attendu: etape.attendu, action: !!etape.action };
    const cible = etape.cible?.(ctx);
    await eteindre(page);
    if (cible) {
      // Timeout court : une cible absente ne doit pas bloquer le guidage.
      // Centrée, pour ne pas finir sous le panneau en bas à droite ; instantané, car le DSFR
      // anime le défilement (scroll-behavior: smooth) et une capture partirait avant la fin.
      await cible.first().evaluate((el) => el.scrollIntoView({ block: 'center', behavior: 'instant' }), null, { timeout: 3000 }).catch(() => {});
      await cible.first().evaluate(SURLIGNER, null, { timeout: 3000 }).catch(() => {});
    }
    await placer(base, etape, ctx);
    const resultat = { etape: i + 1, titre: etape.titre, attendu: etape.attendu };

    if (mode === 'guide') {
      // Le panneau se redessine après chaque navigation via __recetteState.
      let reduit = false;
      if (voix !== null) direGuide(i === 0 ? `${dire.intro} ${dire.etape(i, etape)}` : dire.etape(i, etape));
      await afficher({ ...base, boutons: true, montrerAttendu: true, reduit, voixJusqua });
      for (;;) {
        const ev = await evenement();
        if (ev.type === 'reduire') { reduit = !reduit; await afficher({ ...state, reduit }); continue; }
        if (ev.type === 'fermer') break;
        if (ev.type === 'faire') {
          await afficher({ ...state, fait: true, consigne: '⏳ En cours…' });
          try {
            await etape.action(ctx); await centrer(etape, ctx, true); await placer(state, etape, ctx, true);
            if (voix !== null) direGuide(dire.valider(etape));
            await afficher({ ...state, consigne: '✓ Fait. Vérifiez l’attendu ci-dessous.', voixJusqua });
          }
          catch (err) { await afficher({ ...state, consigne: `⚠ Action impossible : ${err.message.split('\n')[0]}. Faites-la à la main.` }); }
          continue;
        }
        resultat.verdict = ev.type === 'ok' ? 'conforme' : 'non conforme';
        if (ev.payload) resultat.commentaire = ev.payload;
        if (voix !== null) { direGuide(ev.type === 'ok' ? dire.ok : dire.ko(ev.payload ?? '')); await finirPhrase(); }
        break;
      }
      if (ferme || !resultat.verdict) break;
    } else {
      // La voix lit la consigne pendant que l'action se joue, puis l'attendu une fois vérifié.
      const debut = Date.now();
      let voixAvant = 0;
      // Captures : le panneau tel que le voit le relecteur, sans verdict simulé.
      const capturer = (nom) => page.screenshot({ path: join(out, `${String(i + 1).padStart(2, '0')}-${nom}.png`) });
      if (mode === 'captures') {
        await afficher({ ...base, mode: 'guide', boutons: true, montrerAttendu: true });
        await capturer('consigne');
      }
      if (mode === 'video') {
        // Le même panneau que le mode guide : le statut remplace les boutons de verdict.
        await afficher({ ...base, statut: etape.action ? '▶ Le script joue l’action…' : '⏳ Vérification…' });
        voixAvant = parler(etape.narration ?? etape.consigne);
        await pause(1200);
      }
      try {
        await etape.action?.(ctx);
        await etape.verifier?.(ctx);
        resultat.verdict = etape.verifier ? 'vérifié' : 'joué';
      } catch (err) {
        resultat.verdict = 'échec';
        resultat.erreur = err.message.split('\n')[0];
      }
      await centrer(etape, ctx, true);
      await placer(base, etape, ctx, true);
      if (mode === 'captures') {
        const echec = resultat.verdict === 'échec';
        await centrer(etape, ctx, true);
        await afficher({ ...base, mode: 'guide', boutons: true, fait: true, montrerAttendu: true,
          ...(echec ? { echec: resultat.erreur } : { consigne: '✓ Fait. Vérifiez l’attendu ci-dessous.' }) });
        await capturer('attendu');
      }
      if (mode === 'video') {
        await tenir(debut, 2200, voixAvant);
        // La vidéo n'affiche et ne dit l'attendu qu'une fois vérifié : elle ne doit rien affirmer de faux.
        const echec = resultat.verdict === 'échec';
        await afficher({ ...base, ...(echec ? { echec: resultat.erreur } : { montrerAttendu: true, statut: '✓ Vérifié par le script' }) });
        const apres = Date.now();
        await tenir(apres, 2800, parler(echec ? `Échec de l'étape ${i + 1}.` : etape.attendu));
      }
    }

    // La page a pu défiler depuis (chargement, action) : la capture doit montrer ce qu'on juge.
    await centrer(etape, ctx, !!resultat.verdict);
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
    if (voix !== null) direGuide(dire.fin(resultats.length - ko.length, total));
    await afficher({
      mode, fin: true, entete: 'Recette terminée', voixJusqua,
      titre: `${resultats.length - ko.length}/${total} conformes`,
      consigne: [...ko.map((r) => `❌ ${r.etape}. ${r.titre}${r.commentaire ? ` — ${r.commentaire}` : ''}`),
        `Rapport : ${join(out, 'rapport.md')}`].join('\n')
    });
    await evenement();
    await finirPhrase(); // filmé : ne pas couper la dernière phrase
  }

  if (mode === 'video') {
    const echec = resultats.find((r) => r.verdict === 'échec');
    await afficher({ mode, entete: `PR #${scenario.pr}`, titre: echec ? `✗ Recette en échec à l'étape ${echec.etape}` : 'Fin de la recette', echec: echec?.erreur });
    const debut = Date.now();
    await tenir(debut, 1500, parler(echec ? `Recette en échec à l'étape ${echec.etape}.` : finOk));
  }
  if (!ferme) await eteindre(page);
  await context.close();
  await browser.close();

  ecrireRapport();
  if (filmer) {
    const webm = readdirSync(out).find((f) => f.endsWith('.webm'));
    const nom = `recette-pr-${scenario.pr}${mode === 'guide' ? '-guide' : ''}`;
    const mp4 = join(out, `${nom}.mp4`);
    // Chaque phrase est posée à son horodatage, puis mixée sans normalisation (repris de /demo-pr).
    const audio = pistes.length ? [
      ...pistes.flatMap((p) => ['-i', p.file]),
      '-filter_complex', [
        ...pistes.map((p, i) => `[${i + 1}]adelay=delays=${p.debut}:all=1[a${i}]`),
        `${pistes.map((_, i) => `[a${i}]`).join('')}amix=inputs=${pistes.length}:normalize=0[a]`
      ].join(';'),
      '-map', '0:v', '-map', '[a]', '-c:a', 'aac', '-b:a', '128k'
    ] : [];
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', join(out, webm), ...audio,
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '28', '-movflags', '+faststart', mp4]);
    renameSync(join(out, webm), join(out, `${nom}.webm`));
    console.log(`vidéo : ${mp4}${pistes.length ? ` (voix off : ${voix || 'voix système'})` : ' (muette)'}`);
  }
  console.log(`résultats : ${join(out, 'resultats.json')}`);
  process.exitCode = resultats.some((r) => ['échec', 'non conforme'].includes(r.verdict)) || resultats.length < total ? 1 : 0;
}

await main();
