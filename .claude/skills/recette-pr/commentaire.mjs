#!/usr/bin/env node
// Écrit le commentaire de recette d'une PR : persona et contexte en tête, puis un accordéon
// par critère d'acceptation (titre et verdict sur le bouton ; consigne, attendu et captures pleine largeur dedans).
//   node commentaire.mjs <scenario.mjs> <resultats.json> <url des images> [--video <url>] [--a-juger <fichier.md>]
// --a-juger : constats de la recette à trancher par l'humain (markdown), placés juste après le contexte.
// Les images s'appellent NN-consigne.png et NN-attendu.png (mode captures).
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

const { values: opts, positionals } = parseArgs({ allowPositionals: true, options: { video: { type: 'string' }, 'a-juger': { type: 'string' } } });
const [scenarioPath, resultatsPath, images] = positionals;
if (!images) {
  console.error('usage: commentaire.mjs <scenario.mjs> <resultats.json> <url des images> [--video <url>] [--a-juger <fichier.md>]');
  process.exit(1);
}

const scenario = (await import(pathToFileURL(resolve(scenarioPath)))).default;
const lus = JSON.parse(readFileSync(resultatsPath, 'utf8'));
const { resultats } = lus;
// Résultats antérieurs au champ juge : le mode guide était jugé par un humain, les autres par le script.
const juge = lus.juge ?? (lus.mode === 'guide' ? 'humain' : 'script');
// Un ✅ ne sort que d'un humain : le script vérifie (🤖), un agent qui joue le relecteur juge (🤖 aussi).
const icone = { vérifié: '🤖', joué: '▶️', échec: '❌', conforme: juge === 'humain' ? '✅' : '🤖', 'non conforme': '❌' };
const total = scenario.etapes.length;
const bilan = {
  script: `${resultats.filter((r) => r.verdict === 'vérifié').length}/${total} vérifiés par le script 🤖`,
  humain: `${resultats.filter((r) => r.verdict === 'conforme').length}/${total} jugés conformes par un humain ✅`,
  agent: `${resultats.filter((r) => r.verdict === 'conforme').length}/${total} jugés conformes par un agent 🤖 (aucun verdict humain)`
}[juge];
const cite = (t) => String(t ?? '').replace(/\n/g, ' ');
const source = readFileSync(resolve(scenarioPath), 'utf8').trimEnd();
const N = scenario.pr;
const aJuger = opts['a-juger'] ? readFileSync(opts['a-juger'], 'utf8').trim() : null;
// Variables d'environnement dont la recette a besoin (scenario.env), rappelées dans le prompt.
const env = Object.entries(scenario.env ?? {}).map(([k, v]) => `${k}=${v}`).join(' ');

// Rejouer : un prompt à coller dans Claude Code, autonome (il embarque le scénario joué).
// Clôture à quatre accents graves : le scénario
// est lui-même dans un bloc de code.
const rejouer = [
  '### Rejouer en local',
  '',
  'Copiez ce prompt dans Claude Code, à la racine du dépôt : il prépare la PR en local et ouvre la recette guidée avec ce même scénario.',
  '',
  '<details>',
  '<summary><b>Prompt à copier</b></summary>',
  '',
  '````text',
  `Avec le skill /recette-pr, rejoue la recette guidée de la PR #${N} :`,
  `1. prépare et lance la PR en local (prepare.sh ${N} puis serve.sh ${N})${env ? `, avec ${env} pour serve.sh et recette.mjs` : ''} ;`,
  `2. enregistre le scénario ci-dessous tel quel dans ../review-pr-${N}/tmp/recette/scenario.mjs, sans le réécrire ;`,
  '3. vérifie-le en mode auto, puis ouvre la recette guidée (mode guide) pour que je donne mes verdicts ;',
  '4. à la fin, résume mes verdicts et propose le commentaire à poster sur la PR.',
  '',
  '```js',
  source,
  '```',
  '````',
  '',
  '</details>',
  '',
].join('\n');

// Un accordéon par critère d'acceptation (une étape du scénario) : le bouton dit seulement quoi (numéro, titre, verdict),
// le dépliage donne la consigne, l'attendu et les captures en pleine largeur.
const etapes = scenario.etapes.map((etape, i) => {
  const n = String(i + 1).padStart(2, '0');
  const r = resultats[i];
  return [
    '<details>',
    `<summary>${icone[r?.verdict] ?? '⏸️'} <b>${i + 1}. ${etape.titre}</b></summary>`,
    '',
    `**Consigne** : ${cite(etape.consigne)}`,
    '',
    `**Attendu** : ${cite(etape.attendu)}`,
    ...(r?.erreur ? ['', `**Échec** : \`${cite(r.erreur)}\``] : []),
    '',
    `<img src="${images}/${n}-consigne.png" width="100%" alt="Critère ${i + 1}, avant l'action">`,
    '',
    `<img src="${images}/${n}-attendu.png" width="100%" alt="Critère ${i + 1}, après l'action">`,
    '',
    '</details>',
    ''
  ].join('\n');
});

console.log([
  `## Recette de #${N}`, // guidée ou non : le bilan des critères dit qui a joué et qui a jugé
  '',
  '### Contexte',
  '',
  `${cite(scenario.contexte).replace(/\.$/, '')}${scenario.persona ? ` (persona \`${scenario.persona}\`)` : ''}.`,
  '',
  ...(aJuger ? ['### À juger', '', aJuger, ''] : []),
  '### Validation visuelle',
  '',
  ...(opts.video ? [opts.video, ''] : ['_Vidéo à glisser ici._', '']),
  // Le bilan tient dans le titre ; la fiche dit si un humain a signé les critères ou les a délégués.
  `### Critères d’acceptation : ${bilan}`,
  '',
  ...(scenario.fiche ? [`_Fiche de critères ${scenario.fiche}._`, ''] : []),
  ...etapes,
  rejouer
].join('\n'));
