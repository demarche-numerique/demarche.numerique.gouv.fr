// Garde-fou contre le crash du perf-track dev de React 19.2 avec les sections
// react-aria : `addObjectDiffToProperties` évalue un getter (`childNodes`) qui
// lève une exception sur les nœuds de collection, gelant le composant à la
// sélection / frappe. Ce comportement est neutralisé par le patch
// `patches/react-dom@<version>.patch`. Ce test reproduit la structure d'une
// combobox react-aria à sections (AriaComboBox + Virtualizer + Collection de
// sections), celle que Select.tsx partage via Autocomplete, et échoue
// si le patch n'est plus appliqué (typiquement après un bump de react-dom dont
// la clé `patchedDependencies` n'a pas suivi).
import './process-env-shim';
import { suite, test, expect, beforeEach, afterEach } from 'vitest';
import { userEvent, page } from '@vitest/browser/context';
import { useState } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import {
  ComboBox as AriaComboBox,
  ListBox,
  ListBoxItem,
  ListBoxSection,
  Header,
  Popover,
  Input,
  Button,
  Collection,
  Virtualizer,
  ListLayout
} from 'react-aria-components';

type Item = { label: string; value: string };
type Section = { label: string; items: Item[] };

function buildSections(): Section[] {
  return [
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
    }
  ];
}

function ComboBoxWithSections() {
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const sections = buildSections();

  return (
    <AriaComboBox
      aria-label="Démarches"
      menuTrigger="focus"
      selectedKey={selectedKey}
      onSelectionChange={(key) =>
        setSelectedKey(key == null ? null : String(key))
      }
      shouldFocusWrap
    >
      <Input aria-label="Démarches" />
      <Button>open</Button>
      <Popover>
        <Virtualizer layout={ListLayout}>
          <ListBox style={{ height: 300, width: 300 }}>
            <Collection items={sections}>
              {(section) => (
                <ListBoxSection id={section.label}>
                  <Header>{section.label}</Header>
                  <Collection items={section.items}>
                    {(item) => (
                      <ListBoxItem id={item.value}>{item.label}</ListBoxItem>
                    )}
                  </Collection>
                </ListBoxSection>
              )}
            </Collection>
          </ListBox>
        </Virtualizer>
      </Popover>
    </AriaComboBox>
  );
}

suite('ComboBox sections (React 19 perf-track)', () => {
  let container: HTMLDivElement;
  let root: Root;
  const errors: unknown[] = [];
  const onError = (e: ErrorEvent) => errors.push(e.error ?? e.message);

  beforeEach(() => {
    errors.length = 0;
    window.addEventListener('error', onError);
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(() => {
    window.removeEventListener('error', onError);
    root.unmount();
    container.remove();
  });

  test('typing in a sectioned combobox does not freeze the component', async () => {
    root.render(<ComboBoxWithSections />);

    const input = page.getByRole('combobox', { name: 'Démarches' });
    await userEvent.click(input);

    // La frappe filtre la collection des sections, donc déclenche un re-render
    // que le perf-track dev de React diffe (et donc l'évaluation des getters).
    await userEvent.type(input, 'Rhô');

    // laisser passer les passive effects (le perf-track tourne après le commit)
    await new Promise((resolve) => setTimeout(resolve, 300));

    // sans le patch : crash « childNodes is not supported » → input gelé sur « R »
    await expect.element(input).toHaveValue('Rhô');
    expect(
      errors,
      `erreurs non capturées: ${errors.map(String).join('; ')}`
    ).toEqual([]);
  });
});
