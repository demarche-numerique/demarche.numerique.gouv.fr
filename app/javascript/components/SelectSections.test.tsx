// Reproduit la MÊME structure que Select.tsx avec des sections (AriaSelect +
// Autocomplete + Virtualizer + Collection de sections) — Select.tsx ne peut pas
// être importé directement ici car il dépend de la macro Lingui, non configurée
// dans vitest (même contrainte que ComboBoxSections.test.tsx). Vérifie que les
// en-têtes de section s'affichent, que le filtre masque les sections vides et
// que la sélection fonctionne.
import './process-env-shim';
import { suite, test, expect, beforeEach, afterEach } from 'vitest';
import { userEvent, page } from '@vitest/browser/context';
import { useState, type Key } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import {
  Select as AriaSelect,
  Autocomplete,
  SelectValue,
  Button,
  Popover,
  Virtualizer,
  ListLayout,
  ListBoxSection,
  Collection,
  Header,
  useFilter
} from 'react-aria-components';

import { SearchField } from './react-aria/components/SearchField';
import {
  DropdownListBox as SelectListBox,
  DropdownItem as SelectItem
} from './react-aria/components/ListBox';

type Item = { label: string; value: string };
type Section = { label: string; items: Item[] };

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
  const [value, setValue] = useState<string | null>(null);
  const { contains } = useFilter({ sensitivity: 'base', numeric: true });

  return (
    <AriaSelect
      aria-label="Organisme"
      selectionMode="single"
      value={value}
      disabledKeys={disabledKeys}
      onChange={(key: Key | null) => setValue(key ? String(key) : null)}
    >
      <Button className="fr-select">
        <SelectValue />
      </Button>
      <Popover>
        <Autocomplete<Item> filter={contains}>
          <SearchField autoFocus />
          <Virtualizer layout={ListLayout}>
            <SelectListBox>
              <Collection items={sections}>
                {(section) => (
                  <ListBoxSection id={section.label}>
                    <Header>{section.label}</Header>
                    <Collection items={section.items}>
                      {(item) => (
                        <SelectItem id={item.value}>{item.label}</SelectItem>
                      )}
                    </Collection>
                  </ListBoxSection>
                )}
              </Collection>
            </SelectListBox>
          </Virtualizer>
        </Autocomplete>
      </Popover>
    </AriaSelect>
  );
}

suite('Select avec sections', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
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

    const button = page.getByRole('button', { name: 'Organisme' });
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
    await userEvent.click(
      page.getByRole('option', { name: 'Préfecture du Rhône' })
    );
    await expect.element(button).toHaveTextContent('Préfecture du Rhône');
  });

  test('affiche un item désactivé sans permettre de le sélectionner', async () => {
    root.render(<SelectWithSections />);

    const button = page.getByRole('button', { name: 'Organisme' });
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
