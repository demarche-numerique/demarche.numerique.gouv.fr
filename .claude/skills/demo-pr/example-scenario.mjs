// Demo of PR #14604 (single "Date" entry in the types de champ menu), on a draft procedure
// seeded with champs "A – Date simple", "B – Date et heure existante"…
// Each scene: `say` is read aloud while `run` acts; the scene lasts at least as long as the sentence.
const champ = (page, libelle) =>
  page.locator('li.type-de-champ').filter({ has: page.locator(`input[value="${libelle}"]`) });
const lastChamp = (page) => page.locator('li.type-de-champ').last();
const TIME_LABEL = 'Cette date comprend aussi une heure';

export default {
  login: { email: 'admin@exemple.fr', password: 'this is a very complicated password !' }, // omit for an anonymous demo
  start: '/admin/procedures/26/champs', // id printed by your runner script
  scenes: [
    {
      say: "Démonstration de la pull request 14604. Le menu des types de champ ne propose plus qu'une seule entrée Date. Le choix entre date, et date et heure, se fait avec un interrupteur.",
      run: async ({ page, pause, focus }) => {
        await pause(1500);
        await focus(champ(page, 'A – Date simple').locator('.fr-select').first(), 2500);
      },
    },
    {
      say: "J'ajoute un champ, et j'ouvre le menu des types. On ne trouve qu'une seule entrée Date.",
      run: async ({ page, focus, waitText }) => {
        await page.getByRole('button', { name: 'Ajouter un champ' }).last().click();
        await waitText('Formulaire enregistré');
        await lastChamp(page).locator('button.fr-select').first().click();
        const option = page.getByRole('option', { name: 'Date', exact: true });
        await option.scrollIntoViewIfNeeded();
        await focus(option, 2500);
      },
    },
    {
      say: "Je choisis Date, puis j'active l'interrupteur : le champ devient une date et heure, et le formulaire est enregistré.",
      run: async ({ page, focus, waitText }) => {
        await page.getByRole('option', { name: 'Date', exact: true }).click();
        await waitText('Formulaire enregistré');
        const toggle = lastChamp(page).locator('label', { hasText: TIME_LABEL });
        await focus(toggle, 1500);
        await toggle.click();
        await waitText('Formulaire enregistré');
      },
    },
    {
      say: "Après rechargement de la page, l'interrupteur est toujours activé.",
      run: async ({ page, focus }) => {
        await page.reload();
        await page.waitForLoadState('networkidle');
        await focus(lastChamp(page).locator('label', { hasText: TIME_LABEL }), 2500);
      },
    },
  ],
};
