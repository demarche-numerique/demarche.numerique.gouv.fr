import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { page, userEvent } from 'vitest/browser';
import { createRoot, type Root } from 'react-dom/client';
import { flushSync } from 'react-dom';
import type { Feature, FeatureCollection } from 'geojson';

import {
  ReadableFeatureCollectionProvider,
  useFeature,
  WritableFeatureCollectionProvider
} from './FeatureCollectionProvider';
import { DescriptionInput } from './DescriptionInput';

vi.mock('@lingui/react/macro', () => ({
  useLingui: () => ({
    t: (s: TemplateStringsArray | string) => String(s),
    i18n: { locale: 'fr' }
  })
}));

function point(id: string, description?: string): Feature {
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [2.35, 48.85] },
    properties: { id, source: 'selection_utilisateur', description }
  };
}

const rendered = vi.fn<(id: string) => void>();

function renders(id: string) {
  return rendered.mock.calls.filter(([called]) => called == id).length;
}

function Line({ id }: { id: string }) {
  const feature = useFeature(id);
  rendered(id);
  return <p data-id={id}>{feature?.properties?.description}</p>;
}

function EditableLine({ id }: { id: string }) {
  const feature = useFeature(id);
  rendered(id);
  return <DescriptionInput id={id} label={String(feature?.properties?.id)} />;
}

suite('ReadableFeatureCollectionProvider', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
    rendered.mockClear();
  });

  afterEach(() => {
    root.unmount();
    container.remove();
  });

  // The same lines each time, as the list of the champ: only the collection
  // changes.
  const lines = (
    <>
      <Line id="a" />
      <Line id="b" />
    </>
  );

  function render(featureCollection: FeatureCollection) {
    flushSync(() =>
      root.render(
        <ReadableFeatureCollectionProvider
          featureCollection={featureCollection}
        >
          {lines}
        </ReadableFeatureCollectionProvider>
      )
    );
  }

  test('renders again only the line of the feature that changed', () => {
    const b = point('b', 'Le verger');
    render({ type: 'FeatureCollection', features: [point('a'), b] });
    expect(renders('a')).toBe(1);
    expect(renders('b')).toBe(1);

    render({
      type: 'FeatureCollection',
      features: [point('a', 'Mon jardin'), b]
    });

    expect(container.querySelector('[data-id=a]')?.textContent).toBe(
      'Mon jardin'
    );
    expect(renders('a')).toBe(2);
    expect(renders('b')).toBe(1);
  });
});

suite('WritableFeatureCollectionProvider', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
    rendered.mockClear();
  });

  afterEach(() => {
    root.unmount();
    container.remove();
  });

  test('renders again only the line of the description typed in', async () => {
    root.render(
      <WritableFeatureCollectionProvider
        featureCollection={{
          type: 'FeatureCollection',
          features: [point('a'), point('b')]
        }}
      >
        <EditableLine id="a" />
        <EditableLine id="b" />
      </WritableFeatureCollectionProvider>
    );
    const input = page.getByLabelText('Description (a)');
    await expect.element(input).toBeInTheDocument();
    const before = { a: renders('a'), b: renders('b') };

    await userEvent.type(input, 'Mon jardin');

    // Typed key by key, the controlled input keeps every key.
    await expect.element(input).toHaveValue('Mon jardin');
    expect(renders('a')).toBeGreaterThan(before.a);
    expect(renders('b')).toBe(before.b);
  });
});
