// Un champ référentiel déjà rempli est réhydraté avec l'élément sélectionné, sans
// jeton `data` (seules les suggestions du serveur en portent un). react-aria signale
// le clic sur l'élément déjà sélectionné comme un changement de sélection : la
// combobox ne doit alors rien soumettre, sinon l'autosave envoie une valeur que le
// serveur ne peut pas déchiffrer (RAILS-JYH). Chaque recherche chiffre un nouveau
// jeton pour la même donnée : resélectionner une suggestion soumet le plus récent,
// le serveur refusant un jeton expiré.
import './process-env-shim';
import { vi, suite, test, expect, beforeEach, afterEach } from 'vite-plus/test';
import { userEvent, page } from 'vite-plus/test/browser/context';
import { createRoot, type Root } from 'react-dom/client';

import { RemoteComboBox, ComboBoxValueSlot } from './ComboBox';
import type { Loader } from './react-aria/hooks';

vi.mock('@lingui/react/macro', () => ({
  useLingui: () => ({ t: (s: TemplateStringsArray | string) => String(s) }),
  Trans: ({ children }: { children: React.ReactNode }) => children,
  Plural: ({ _0, value }: { _0: React.ReactNode; value: number }) =>
    value === 0 ? _0 : `${value} choix sélectionnés`
}));

let searches: number;
const loader: Loader = async ({ filterText }) => ({
  items: filterText
    ? [
        {
          id: 'md5-lyon',
          label: 'Lyon',
          value: 'Lyon',
          data: `token-lyon-${++searches}`
        }
      ]
    : []
});

function Champ() {
  return (
    <form>
      <RemoteComboBox
        label="Ville"
        loader={loader}
        items={[{ label: 'Paris', value: 'Paris' }]}
        selectedKey="Paris"
        name="champ[value]"
        minimumInputLength={0}
        debounce={0}
      >
        <ComboBoxValueSlot field="data" name="champ[data]" />
      </RemoteComboBox>
    </form>
  );
}

let container: HTMLDivElement;
let root: Root;
let changes: number;

beforeEach(() => {
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
  changes = 0;
  searches = 0;
  container.addEventListener('change', () => changes++);
  root.render(<Champ />);
});

afterEach(() => {
  root.unmount();
  container.remove();
});

function hiddenInput(name: string) {
  return container.querySelector<HTMLInputElement>(`input[name="${name}"]`)!;
}

// La liste ouverte contient l'élément présélectionné (Paris) puis la suggestion (Lyon).
suite('RemoteComboBox with a preselected item', () => {
  test('re-selecting the current item submits nothing', async () => {
    const input = page.getByRole('combobox', { name: 'Ville' });
    await expect.element(input).toHaveValue('Paris');
    expect(hiddenInput('champ[data]').value).toBe('');

    await userEvent.fill(input, 'Par');
    await expect
      .element(page.getByRole('option', { name: 'Lyon' }))
      .toBeVisible();
    await userEvent.keyboard('{Enter}');

    await expect.element(input).toHaveValue('Paris');
    await new Promise((resolve) => requestAnimationFrame(resolve));
    expect(changes).toBe(0);
    expect(hiddenInput('champ[value]').value).toBe('Paris');
    expect(hiddenInput('champ[data]').value).toBe('');
  });

  test('selecting a suggestion submits its token', async () => {
    const input = page.getByRole('combobox', { name: 'Ville' });

    await userEvent.fill(input, 'Lyo');
    await expect
      .element(page.getByRole('option', { name: 'Lyon' }))
      .toBeVisible();
    await userEvent.keyboard('{ArrowDown}{Enter}');

    await expect.element(input).toHaveValue('Lyon');
    await expect.poll(() => changes).toBe(1);
    expect(hiddenInput('champ[value]').value).toBe('Lyon');
    expect(hiddenInput('champ[data]').value).toBe('token-lyon-1');
  });

  test('re-selecting a suggestion after a new search submits its fresh token', async () => {
    const input = page.getByRole('combobox', { name: 'Ville' });

    await userEvent.fill(input, 'Lyo');
    await expect
      .element(page.getByRole('option', { name: 'Lyon' }))
      .toBeVisible();
    await userEvent.keyboard('{ArrowDown}{Enter}');
    await expect.poll(() => changes).toBe(1);

    await userEvent.fill(input, 'Ly');
    await expect.poll(() => searches).toBe(2);
    await expect
      .element(page.getByRole('option', { name: 'Lyon' }))
      .toBeVisible();
    await userEvent.keyboard('{ArrowDown}{Enter}');

    await expect.element(input).toHaveValue('Lyon');
    await expect.poll(() => changes).toBe(2);
    expect(hiddenInput('champ[data]').value).toBe('token-lyon-2');
  });
});
