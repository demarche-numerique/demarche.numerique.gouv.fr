import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { page } from 'vitest/browser';
import { createRoot, type Root } from 'react-dom/client';
import type { FeatureCollection } from 'geojson';

import { ReadableFeatureCollectionProvider } from './FeatureCollectionProvider';
import { FeatureLink } from './FeatureLink';

type FakeMap = {
  fitBounds: ReturnType<typeof vi.fn>;
  getContainer: () => { clientWidth: number; clientHeight: number };
};

const map = vi.hoisted(() => ({ current: undefined as FakeMap | undefined }));

vi.mock('./MapLibreProvider', () => ({
  useMapLibre: () => map.current
}));

const featureCollection: FeatureCollection = {
  type: 'FeatureCollection',
  features: [
    {
      type: 'Feature',
      geometry: {
        type: 'LineString',
        coordinates: [
          [2.35, 48.85],
          [2.36, 48.87]
        ]
      },
      properties: { id: 'line', source: 'selection_utilisateur' }
    }
  ]
};

suite('FeatureLink', () => {
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
    map.current = undefined;
  });

  function render() {
    root.render(
      <ReadableFeatureCollectionProvider featureCollection={featureCollection}>
        <FeatureLink id="line">Une ligne</FeatureLink>
      </ReadableFeatureCollectionProvider>
    );
  }

  test('fits the map to the feature', async () => {
    map.current = {
      fitBounds: vi.fn(),
      getContainer: () => ({ clientWidth: 800, clientHeight: 500 })
    };
    render();

    await page.getByRole('button', { name: 'Une ligne' }).click();

    expect(map.current.fitBounds).toHaveBeenCalledOnce();
    const [bounds, options] = map.current.fitBounds.mock.calls[0];
    expect(bounds.toArray()).toEqual([
      [2.35, 48.85],
      [2.36, 48.87]
    ]);
    expect(options).toEqual({
      padding: { top: 125, bottom: 125, left: 200, right: 200 },
      maxZoom: 18
    });
  });

  test('is plain text as long as there is no map', async () => {
    render();

    await expect.element(page.getByText('Une ligne')).toBeInTheDocument();
    expect(container.querySelector('button')).toBeNull();
  });
});
