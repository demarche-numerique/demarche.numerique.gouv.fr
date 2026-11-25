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
  console.error('usage: commentaire.mjs <scenario.mjs> <resultats.json> <url des images> [--video <url>]');
  process.exit(1);
}

const scenario = (await import(pathToFileURL(resolve(scenarioPath)))).default;
const { resultats } = JSON.parse(readFileSync(resultatsPath, 'utf8'));
const icone = { vérifié: '🤖', joué: '▶️', échec: '❌', conforme: '✅', 'non conforme': '❌' };
const verifiees = resultats.filter((r) => r.verdict === 'vérifié').length;
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
    `<img src="${images}/${n}-consigne.png" width="100%" alt="Étape ${i + 1}, avant l'action">`,
    '',
    `<img src="${images}/${n}-attendu.png" width="100%" alt="Étape ${i + 1}, après l'action">`,
    '',
    '</details>',
    ''
  ].join('\n');
});

console.log([
  `## Recette guidée de #${N}`,
  '',
  '### Contexte',
  '',
  `${cite(scenario.contexte).replace(/\.$/, '')}${scenario.persona ? ` (persona \`${scenario.persona}\`)` : ''}.`,
  '',
  ...(aJuger ? ['### À juger', '', aJuger, ''] : []),
  '### Validation visuelle',
  '',
  ...(opts.video ? [opts.video, ''] : ['_Vidéo à glisser ici._', '']),
  // Le bilan tient dans le titre : 🤖 tant qu'aucun humain n'a jugé.
  `### Critères d’acceptation : ${verifiees}/${scenario.etapes.length} vérifiés par le script 🤖`,
  '',
  ...etapes,
  rejouer
].join('\n'));
