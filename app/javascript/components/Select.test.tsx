import './process-env-shim';
import '@gouvfr/dsfr/dist/core/core.min.css';
import '@gouvfr/dsfr/dist/component/select/select.min.css';
import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { userEvent, page } from '@vitest/browser/context';
import { createRoot, type Root } from 'react-dom/client';
import { MultipleSelect, SingleSelect } from './Select';

vi.mock('@lingui/react/macro', () => ({
  useLingui: () => ({ t: (s: TemplateStringsArray | string) => String(s) }),
  Trans: ({ children }: { children: React.ReactNode }) => children,
  Plural: ({ _0, value }: { _0: React.ReactNode; value: number }) =>
    value === 0 ? _0 : `${value} choix sélectionnés`
}));

const sections = [
  {
    label: 'Identité',
    items: [{ label: 'Nom', value: 'nom', mandatory: true }]
  },
  {
    label: 'Adresse',
    items: [{ label: 'Domicile', value: 'domicile' }]
  }
];

suite('MultipleSelect with sections', () => {
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

  test('renders section headers and a mandatory asterisk', async () => {
    root.render(
      <MultipleSelect
        name="champs[]"
        sections={sections}
        value={[]}
        aria-label="Champs"
      />
    );

    await userEvent.click(page.getByRole('button'));

    await expect.element(page.getByText('Identité')).toBeInTheDocument();
    await expect.element(page.getByText('Adresse')).toBeInTheDocument();
    await expect
      .element(page.getByRole('option', { name: 'Nom *' }))
      .toBeInTheDocument();
    await expect
      .element(page.getByRole('option', { name: 'Domicile' }))
      .toBeInTheDocument();
  });

  test('shows emptyHint when nothing is selected and tags once a field is picked', async () => {
    root.render(
      <MultipleSelect
        name="champs[]"
        sections={sections}
        value={[]}
        aria-label="Champs"
        emptyHint="Affichage non personnalisé"
      />
    );

    await expect
      .element(page.getByText('Affichage non personnalisé'))
      .toBeInTheDocument();

    await userEvent.click(page.getByRole('button'));
    await userEvent.click(page.getByRole('option', { name: 'Domicile' }));

    await expect
      .element(page.getByText('Affichage non personnalisé'))
      .not.toBeInTheDocument();
    await expect
      .element(
        page.getByRole('list', { name: 'Sélection' }).getByText('Domicile')
      )
      .toBeInTheDocument();
  });

  test('uses selectedLabels when provided', async () => {
    root.render(
      <MultipleSelect
        name="champs[]"
        sections={sections}
        aria-label="Champs"
        value={['nom']}
        selectedLabels={{
          one: '1 champ sélectionné',
          other: '# champs sélectionnés'
        }}
      />
    );

    await expect
      .element(page.getByText('1 champ sélectionné'))
      .toBeInTheDocument();
    await expect
      .element(page.getByText(/choix sélectionné/))
      .not.toBeInTheDocument();
  });
});

suite('MultipleSelect labelled by a Rails label', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    container = document.createElement('div');
    container.innerHTML = '<label id="champ-label">Menu</label>';
    document.body.appendChild(container);
    const mount = document.createElement('div');
    container.appendChild(mount);
    root = createRoot(mount);
    root.render(
      <MultipleSelect
        name="champs[]"
        items={[
          { label: 'Entrée', value: 'entree' },
          { label: 'Plat', value: 'plat' }
        ]}
        value={['entree', 'plat']}
        labelId="champ-label"
        aria-describedby="champ-hint"
      />
    );
  });

  afterEach(() => {
    root.unmount();
    container.remove();
  });

  test('describes the trigger with the selected count, keeping its description', async () => {
    const button = page.getByRole('button', { name: /Menu/ });
    await expect.element(button).toBeInTheDocument();

    const describedby = button.element().getAttribute('aria-describedby');
    const ids = describedby?.split(' ') ?? [];
    expect(ids).toContain('champ-hint');
    const count = ids
      .map((id) => document.getElementById(id))
      .find((el) => el?.textContent == '2 choix sélectionnés');
    expect(count).toBeDefined();
  });

  test('lets the focus ring of the trigger show', async () => {
    const button = page.getByRole('button', { name: /Menu/ });
    await expect.element(button).toBeInTheDocument();

    let el = button.element().parentElement;
    while (el && el != container) {
      expect(getComputedStyle(el).overflow).toBe('visible');
      el = el.parentElement;
    }
  });

  test('keeps the trigger background on hover, like a DSFR select', async () => {
    const button = page.getByRole('button', { name: /Menu/ });
    await expect.element(button).toBeInTheDocument();
    const idle = getComputedStyle(button.element()).backgroundColor;

    await userEvent.hover(button);

    expect(getComputedStyle(button.element()).backgroundColor).toBe(idle);
  });

  test('writes the trigger text in the color of a DSFR select', async () => {
    const button = page.getByRole('button', { name: /Menu/ });
    await expect.element(button).toBeInTheDocument();
    const value = button.element().querySelector('.react-aria-SelectValue')!;

    expect(getComputedStyle(value).color).toBe(
      getComputedStyle(button.element()).color
    );
  });

  test('labels the search field with the champ label', async () => {
    await userEvent.click(page.getByRole('button', { name: /Menu/ }));

    await expect
      .element(page.getByRole('searchbox'))
      .toHaveAccessibleName('Menu');
  });
});

suite('SingleSelect with a section id equal to an item value', () => {
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

  test('still filters the options', async () => {
    root.render(
      <SingleSelect
        name="type"
        value={null}
        aria-label="Type"
        sections={[
          {
            id: 'referentiel',
            label: 'Référentiel',
            items: [{ label: 'Référentiel configurable', value: 'referentiel' }]
          },
          {
            id: 'choice',
            label: 'Choix',
            items: [{ label: 'Choix simple', value: 'drop_down_list' }]
          }
        ]}
      />
    );

    await userEvent.click(page.getByRole('button'));
    await userEvent.type(page.getByRole('searchbox'), 'simple');
    await expect
      .element(page.getByRole('option', { name: 'Choix simple', exact: true }))
      .toBeVisible();
    expect(
      page.getByRole('option', { name: 'Référentiel configurable' }).query()
    ).toBeNull();
  });
});

suite('SingleSelect inside a form', () => {
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

  test('mirrors the value and the data attributes on the input carrying the change event', async () => {
    const changes: string[] = [];
    container.addEventListener('change', (event) => {
      const input = event.target as HTMLInputElement;
      changes.push(`${input.dataset.autosubmitTarget}=${input.value}`);
    });
    root.render(
      <form>
        <SingleSelect
          name="procedure_id"
          value={null}
          aria-label="Démarche"
          items={[
            { label: 'Aide', value: '1' },
            { label: 'Subvention', value: '2' }
          ]}
          data={{ autosubmit_target: 'input' }}
        />
      </form>
    );

    await userEvent.click(page.getByRole('button'));
    await userEvent.click(page.getByRole('option', { name: 'Subvention' }));

    await expect.poll(() => changes).toEqual(['input=2']);
    expect(
      container.querySelector<HTMLSelectElement>('select[name="procedure_id"]')
        ?.value
    ).toBe('2');
  });
});

const decoratedItems = [
  {
    label: 'Texte court',
    value: 'text',
    icon: 'fr-icon-text',
    description: 'Une seule ligne'
  },
  { label: 'Texte long', value: 'textarea', icon: 'fr-icon-align-left' },
  { label: 'Date', value: 'date' }
];

suite('SingleSelect with icons and descriptions', () => {
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

  const render = () =>
    root.render(
      <SingleSelect
        name="type_champ"
        items={decoratedItems}
        value={null}
        aria-label="Type de champ"
      />
    );

  // the collection keeps hidden copies of the options: count visible ones only
  const visibleCount = (text: string) =>
    page
      .getByText(text)
      .elements()
      .filter((el) => el.checkVisibility()).length;

  test('renders the icon and description; only the label names the option', async () => {
    render();
    await userEvent.click(page.getByRole('button'));

    const option = page.getByRole('option', {
      name: 'Texte court',
      exact: true
    });
    await expect.element(option).toBeVisible();
    await expect.element(option).toHaveAccessibleDescription('Une seule ligne');
    expect(
      option.element().querySelector('.fr-icon-text[aria-hidden="true"]')
    ).not.toBeNull();

    // a plain item still renders, without an icon
    const plain = page.getByRole('option', { name: 'Date', exact: true });
    await expect.element(plain).toBeVisible();
    expect(plain.element().querySelector('.dropdown-item__icon')).toBeNull();
  });

  test('filters on the label even though the option is not plain text', async () => {
    render();
    await userEvent.click(page.getByRole('button'));

    await userEvent.type(page.getByRole('searchbox'), 'long');
    await expect
      .element(page.getByRole('option', { name: 'Texte long', exact: true }))
      .toBeVisible();
    await expect.poll(() => visibleCount('Texte court')).toBe(0);
  });

  test('shows the selected icon in the trigger, but not the description', async () => {
    render();
    const button = page.getByRole('button');
    await userEvent.click(button);
    await userEvent.click(
      page.getByRole('option', { name: 'Texte court', exact: true })
    );

    await expect.element(button).toHaveTextContent('Texte court');
    expect(button.element().querySelector('.fr-icon-text')).not.toBeNull();
    await expect.poll(() => visibleCount('Une seule ligne')).toBe(0);
  });
});
