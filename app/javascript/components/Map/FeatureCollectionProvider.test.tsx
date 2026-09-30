import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { createRoot, type Root } from 'react-dom/client';
import { flushSync } from 'react-dom';
import type { Feature, FeatureCollection } from 'geojson';

import {
  ReadableFeatureCollectionProvider,
  useFeature
} from './FeatureCollectionProvider';

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
