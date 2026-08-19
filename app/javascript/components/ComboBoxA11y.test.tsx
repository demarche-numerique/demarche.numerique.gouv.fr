import './process-env-shim';
import { suite, test, expect, beforeEach, afterEach } from 'vitest';
import { createRoot, type Root } from 'react-dom/client';
import { page } from '@vitest/browser/context';
import {
  ComboBox as AriaComboBox,
  Select as AriaSelect,
  SelectValue,
  ListBox,
  ListBoxItem,
  Popover,
  Input,
  Button,
  Virtualizer,
  ListLayout
} from 'react-aria-components';

type Item = { label: string; value: string };

const ITEMS: Item[] = [
  { label: 'Paris', value: '75056' },
  { label: 'Lyon', value: '69123' }
];

function TestComboBox({
  inputId,
  labelId,
  ariaLabelledbyPrefix,
  ...props
}: {
  inputId?: string;
  labelId?: string;
  ariaLabelledbyPrefix?: string;
  'aria-describedby'?: string;
}) {
  const inputAriaLabelledby = ariaLabelledbyPrefix
    ? `${ariaLabelledbyPrefix} ${labelId}`
    : labelId;

  return (
    <AriaComboBox
      aria-label={!labelId ? 'Test' : undefined}
      aria-describedby={props['aria-describedby']}
      menuTrigger="focus"
      selectedKey={null}
      shouldFocusWrap
    >
      <Input
        id={inputId}
        aria-labelledby={inputAriaLabelledby}
        className="fr-select"
      />
      <Popover>
        <Virtualizer layout={ListLayout}>
          <ListBox items={ITEMS}>
            {(item) => <ListBoxItem id={item.value}>{item.label}</ListBoxItem>}
          </ListBox>
        </Virtualizer>
      </Popover>
    </AriaComboBox>
  );
}

function TestSelect({
  triggerId,
  labelId,
  ariaLabelledbyPrefix,
  ...props
}: {
  triggerId?: string;
  labelId?: string;
  ariaLabelledbyPrefix?: string;
  'aria-describedby'?: string;
}) {
  if (labelId) {
    props['aria-labelledby' as keyof typeof props] = [
      ariaLabelledbyPrefix,
      labelId
    ]
      .filter(Boolean)
      .join(' ');
  }

  return (
    <AriaSelect
      aria-label={!labelId ? 'Test' : undefined}
      {...props}
      selectedKey={null}
    >
      <Button id={triggerId} className="fr-select">
        <SelectValue />
      </Button>
      <Popover>
        <Virtualizer layout={ListLayout}>
          <ListBox items={ITEMS}>
            {(item) => <ListBoxItem id={item.value}>{item.label}</ListBoxItem>}
          </ListBox>
        </Virtualizer>
      </Popover>
    </AriaSelect>
  );
}

suite('ComboBox ARIA attributes', () => {
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

  test('inputId sets id on the combobox input for label[for] connection', async () => {
    root.render(<TestComboBox inputId="my-input" labelId="my-label" />);

    const input = page.getByRole('combobox');
    await expect.element(input).toHaveAttribute('id', 'my-input');
    await expect.element(input).toHaveAttribute('aria-labelledby', 'my-label');
  });

  test('aria-labelledby with prefix combines prefix and labelId', async () => {
    root.render(
      <TestComboBox
        inputId="champ-input"
        labelId="champ-label"
        ariaLabelledbyPrefix="repetition-legend"
      />
    );

    const input = page.getByRole('combobox');
    await expect
      .element(input)
      .toHaveAttribute('aria-labelledby', 'repetition-legend champ-label');
  });

  test('aria-describedby propagates from ComboBox wrapper to input', async () => {
    root.render(
      <TestComboBox inputId="desc-input" aria-describedby="my-description" />
    );

    const input = page.getByRole('combobox');
    await expect
      .element(input)
      .toHaveAttribute('aria-describedby', 'my-description');
  });
});

suite('Select ARIA attributes', () => {
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

  test('triggerId sets id on the select button for label[for] connection', async () => {
    root.render(
      <TestSelect triggerId="select-trigger" labelId="select-label" />
    );

    const button = page.getByRole('button');
    await expect.element(button).toHaveAttribute('id', 'select-trigger');
  });

  test('aria-labelledby includes our labelId (react-aria prepends SelectValue id)', async () => {
    root.render(
      <TestSelect
        triggerId="prefixed-trigger"
        labelId="sel-label"
        ariaLabelledbyPrefix="legend-id"
      />
    );

    const button = page.getByRole('button');
    await expect.element(button).toBeVisible();
    const labelledby = button.element().getAttribute('aria-labelledby');
    expect(labelledby).toContain('legend-id');
    expect(labelledby).toContain('sel-label');
  });

  test('aria-labelledby includes labelId without prefix', async () => {
    root.render(
      <TestSelect triggerId="no-prefix-trigger" labelId="only-label" />
    );

    const button = page.getByRole('button');
    await expect.element(button).toBeVisible();
    const labelledby = button.element().getAttribute('aria-labelledby');
    expect(labelledby).toContain('only-label');
  });

  test('aria-describedby propagates from Select wrapper to button', async () => {
    root.render(
      <TestSelect
        triggerId="described-trigger"
        aria-describedby="description-id"
      />
    );

    const button = page.getByRole('button');
    await expect.element(button).toBeVisible();
    const describedby = button.element().getAttribute('aria-describedby');
    expect(describedby).toContain('description-id');
  });
});
