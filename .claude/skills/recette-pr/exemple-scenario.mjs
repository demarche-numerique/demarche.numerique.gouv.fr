// Recette de la PR 14604 — un seul type « Date » dans le menu de l'éditeur.
const champ = (page) => page.locator('.type-de-champ').last();
const toggle = (page, label) => champ(page).getByText(label, { exact: true });
const coche = (page, label) => champ(page).getByLabel(label, { exact: true });
const HEURE = 'Cette date comprend aussi une heure (date et heure)';
const NAISSANCE = 'Ce champ est une date de naissance';
const enregistre = (page) => page.getByText('Formulaire enregistré').first().waitFor();
// Chaque étape part d'un état stable : en mode guide, un clic dans le panneau ferme le menu.
const ouvrirMenu = async (page) => {
  if (await page.locator('.select-popover').isVisible()) return;
  await champ(page).getByRole('button', { name: /Type de champ/ }).click();
  await page.locator('.select-popover input').fill('date');
};
const attendre = async (cond, msg) => {
  for (let i = 0; i < 50; i++) { if (await cond()) return; await new Promise((r) => setTimeout(r, 200)); }
  throw new Error(msg);
};

export default {
  pr: 14604,
  titre: "ETQ admin, je n'ai plus qu'un type de champ « Date » au lieu de deux",
  contexte: "Un administrateur construit le formulaire d'une démarche en brouillon.",
  // Voix off de la vidéo (facultatif) : par défaut, la consigne puis l'attendu de chaque étape.
  narration: "Avant cette PR, l'éditeur proposait deux types : date, et date et heure. Voyons ce qui change pour un administrateur.",
  persona: 'admin@exemple.fr',

  // Deux démarches : une vide pour le parcours, une dont le champ « Date et heure »
  // sert à une règle d'inéligibilité, donc verrouillé.
  preparation: `
    include Logic
    admin = User.find_by!(email: "admin@exemple.fr").administrateur
    creer = ->(libelle) {
      p = Procedure.new(libelle:, description: "Recette", cadre_juridique: "https://www.legifrance.gouv.fr/",
        duree_conservation_dossiers_dans_ds: 3, max_duree_conservation_dossiers_dans_ds: Procedure::OLD_MAX_DUREE_CONSERVATION,
        for_individual: true, administrateurs: [admin], zones: [Zone.first], service: admin.services.first)
      p.draft_revision = p.revisions.build
      p.save!
      p
    }
    vide = creer.("Recette PR 14604 — formulaire vide")
    verrouillee = creer.("Recette PR 14604 — champ verrouillé")
    tdc = verrouillee.draft_revision.add_type_de_champ(type_champ: "datetime", libelle: "Date du rendez-vous")
    verrouillee.draft_revision.update_columns(ineligibilite_enabled: true, ineligibilite_message: "Hors délai",
      ineligibilite_rules: ds_not_eq(champ_value(tdc.stable_id), constant(nil)).to_h)
    puts({ vide: vide.id, verrouillee: verrouillee.id }.to_json)
  `,
  depart: (data) => `/admin/procedures/${data.vide}/champs`,

  etapes: [
    {
      titre: 'Le menu ne propose plus qu’une entrée « Date »',
      consigne: 'Ajoutez un champ puis ouvrez le menu « Type de champ » et tapez « date ».',
      narration: 'On ajoute un champ, et on cherche « date » dans le menu des types.',
      cible: ({ page }) => page.getByRole('button', { name: 'Ajouter un champ' }),
      action: async ({ page }) => {
        await page.getByRole('button', { name: 'Ajouter un champ' }).click();
        await enregistre(page);
        await ouvrirMenu(page);
      },
      attendu: 'Une seule option « Date » ; « Date et heure » n’existe plus dans la liste.',
      verifier: async ({ page }) => {
        const options = await page.locator('.select-popover [role="option"]').allInnerTexts();
        if (!options.includes('Date')) throw new Error(`pas d'option Date : ${options}`);
        if (options.some((o) => /heure/i.test(o))) throw new Error(`option heure encore présente : ${options}`);
      }
    },
    {
      titre: 'Choisir « Date »',
      consigne: 'Dans le menu « Type de champ », sélectionnez « Date ».',
      cible: ({ page }) => champ(page).getByRole('button', { name: /Type de champ/ }),
      action: async ({ page }) => {
        await ouvrirMenu(page);
        await page.locator('.select-popover [role="option"]', { hasText: /^Date$/ }).click();
        await toggle(page, HEURE).waitFor();
      },
      attendu: 'En tête, un encart bleu « Ce champ est une date de naissance » ; dessous, le bloc « Format accepté » qui contient le nouveau réglage « Cette date comprend aussi une heure ».',
      verifier: async ({ page }) => {
        await toggle(page, NAISSANCE).waitFor();
        await champ(page).getByText('Format accepté').waitFor();
      }
    },
    {
      titre: 'Ajouter l’heure',
      consigne: 'Activez « Cette date comprend aussi une heure », attendez « Formulaire enregistré » puis rechargez la page.',
      cible: ({ page }) => toggle(page, HEURE),
      action: async ({ page }) => {
        await toggle(page, HEURE).click();
        await enregistre(page);
        await page.waitForTimeout(500);
        await page.reload();
        await toggle(page, HEURE).scrollIntoViewIfNeeded();
      },
      attendu: 'Après rechargement, le réglage est toujours activé : le champ est devenu une « Date et heure ».',
      verifier: async ({ page }) => {
        if (!(await coche(page, HEURE).isChecked())) throw new Error("le réglage heure n'est pas conservé");
      }
    },
    {
      titre: 'Une date de naissance n’a pas d’heure',
      consigne: 'Sur ce champ date et heure, activez « Ce champ est une date de naissance ».',
      narration: 'Cas limite : une date de naissance ne peut pas avoir d’heure. On la coche sur notre champ date et heure.',
      cible: ({ page }) => toggle(page, NAISSANCE),
      action: async ({ page }) => {
        await toggle(page, NAISSANCE).click();
        await champ(page).getByText('Préremplir avec la date de naissance FranceConnect').waitFor();
      },
      attendu: 'Tout le bloc « Format accepté » disparaît, titre et réglage de l’heure compris ; seule apparaît une case « Préremplir avec la date de naissance FranceConnect ».',
      verifier: async ({ page }) => {
        await attendre(async () => (await champ(page).getByText('Format accepté').count()) === 0, 'Format accepté encore affiché');
        if (await toggle(page, HEURE).count()) throw new Error("le réglage de l'heure est encore affiché");
      }
    },
    {
      titre: 'Retour à une date simple',
      consigne: 'Désactivez « Ce champ est une date de naissance ».',
      cible: ({ page }) => toggle(page, NAISSANCE),
      action: async ({ page }) => {
        await toggle(page, NAISSANCE).click();
        await toggle(page, HEURE).waitFor();
      },
      attendu: '« Format accepté » revient, avec l’heure désactivée : cocher « date de naissance » a bien transformé la date et heure en date.',
      verifier: async ({ page }) => {
        if (await coche(page, HEURE).isChecked()) throw new Error("l'heure est restée activée");
      }
    },
    {
      titre: 'Un champ utilisé par l’éligibilité est verrouillé',
      consigne: 'Ouvrez la démarche « champ verrouillé » : son champ « Date du rendez-vous » sert à une règle d’inéligibilité.',
      action: async ({ page, data }) => {
        await page.goto(`/admin/procedures/${data.verrouillee}/champs`);
        await toggle(page, HEURE).scrollIntoViewIfNeeded();
      },
      cible: ({ page }) => toggle(page, HEURE),
      attendu: 'Les réglages « heure » et « date de naissance » sont grisés, avec l’explication : « « Date du rendez-vous » est utilisé par les règles d’inéligibilité, vous ne pouvez pas modifier son type. »',
      verifier: async ({ page }) => {
        // Le texte cité dans l'attendu est vérifié mot pour mot : il change au fil des rebases.
        await champ(page).getByText('« Date du rendez-vous » est utilisé par les règles d’inéligibilité, vous ne pouvez pas modifier son type.').first().waitFor();
        if (!(await coche(page, HEURE).isDisabled())) throw new Error("le réglage heure n'est pas verrouillé");
        if (!(await coche(page, NAISSANCE).isDisabled())) throw new Error("le réglage date de naissance n'est pas verrouillé");
      }
    }
  ]
};
