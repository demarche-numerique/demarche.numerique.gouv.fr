// Vérifie qu'un Select à sections affiche les en-têtes de section, que le
// filtre masque les sections vides, que la sélection fonctionne et qu'un item
// désactivé reste lisible sans être sélectionnable.
import './process-env-shim';
import { suite, test, expect, beforeEach, afterEach } from 'vite-plus/test';
import { userEvent, page } from 'vite-plus/test/browser/context';
import type { Root } from 'react-dom/client';

import { SingleSelect } from './Select';
import type { Section } from './react-aria/props';
import { createAppRoot } from '../test/react';

const sections: Section[] = [
  {
    label: 'Préfectures',
    items: [
      { label: 'Préfecture de Paris', value: '75' },
      { label: 'Préfecture du Rhône', value: '69' }
    ]
  },
  {
    label: 'Ministères',
    items: [
      { label: "Ministère de l'Intérieur", value: 'interieur' },
      { label: 'Ministère de la Justice', value: 'justice' }
    ]
  },
  {
    label: 'Ambassades',
    items: [{ label: 'Aucun organisme disponible', value: 'ambassades-vide' }]
  }
];

// une section peut n'avoir qu'un item explicatif, rendu non sélectionnable
const disabledKeys = ['ambassades-vide'];

function SelectWithSections() {
  return (
    <SingleSelect
      name="organisme"
      aria-label="Organisme"
      value={null}
      sections={sections}
      disabledKeys={disabledKeys}
    />
  );
}

suite('Select avec sections', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createAppRoot(container);
  });

  afterEach(() => {
    root.unmount();
    container.remove();
  });

  // getByText peut matcher des copies cachées de la collection react-aria :
  // on ne compte que les éléments réellement visibles
  const visibleCount = (text: string) =>
    page
      .getByText(text)
      .elements()
      .filter((el) => el.checkVisibility()).length;

  test('affiche les sections, filtre et sélectionne une option', async () => {
    root.render(<SelectWithSections />);

    const button = page.getByRole('button', {
      name: 'Organisme',
      exact: false
    });
    await userEvent.click(button);

    // les deux sections et leurs options sont visibles à l'ouverture
    await expect
      .element(page.getByRole('option', { name: 'Préfecture du Rhône' }))
      .toBeVisible();
    expect(visibleCount('Préfectures')).toBeGreaterThan(0);
    expect(visibleCount('Ministères')).toBeGreaterThan(0);

    // le filtre masque les sections sans résultat
    const search = page.getByRole('searchbox');
    await userEvent.type(search, 'Rhô');
    await expect
      .element(page.getByRole('option', { name: 'Préfecture du Rhône' }))
      .toBeVisible();
    await expect.poll(() => visibleCount('Ministères')).toBe(0);
    expect(
      page.getByRole('option', { name: 'Préfecture de Paris' }).query()
    ).toBeNull();

    // la sélection met à jour la valeur du select
    await userEvent.keyboard('{ArrowDown}{Enter}');
    await expect.element(button).toMatchTextContent('Préfecture du Rhône');
  });

  test('affiche un item désactivé sans permettre de le sélectionner', async () => {
    root.render(<SelectWithSections />);

    const button = page.getByRole('button', {
      name: 'Organisme',
      exact: false
    });
    await userEvent.click(button);

    // l'item est lisible, annoncé désactivé, et donc hors de portée du clic
    const disabledOption = page.getByRole('option', {
      name: 'Aucun organisme disponible'
    });
    await expect.element(disabledOption).toBeVisible();
    await expect
      .element(disabledOption)
      .toHaveAttribute('aria-disabled', 'true');
  });
});
