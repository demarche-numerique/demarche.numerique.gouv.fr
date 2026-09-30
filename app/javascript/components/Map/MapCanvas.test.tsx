import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { page } from 'vitest/browser';
import { createRoot, type Root } from 'react-dom/client';
import { useEffect } from 'react';
import type { MapRef } from '@vis.gl/react-maplibre';
import type { FeatureCollection } from 'geojson';

import { MapReader } from './MapReader';
import { MapCanvas } from './MapCanvas';
import { useMapLibre } from './MapLibreProvider';
import { ANCHORS } from '../shared/maplibre/styles';

vi.mock('@lingui/react/macro', () => ({
  useLingui: () => ({ t: (s: TemplateStringsArray | string) => String(s) }),
  Trans: ({ children }: { children: React.ReactNode }) => children
}));

// No tile ever loads here: the layers are what is under test, not the tiles.
// The map reports every failed request on the console: keep it quiet.
vi.stubGlobal('fetch', () => Promise.reject(new Error('offline')));
vi.spyOn(console, 'error').mockImplementation(() => {});

const featureCollection: FeatureCollection = {
  type: 'FeatureCollection',
  bbox: [2.428, 46.538, 2.429, 46.539],
  features: [
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [
          [
            [2.428, 46.538],
            [2.429, 46.538],
            [2.429, 46.539],
            [2.428, 46.538]
          ]
        ]
      },
      properties: { id: 'shape', source: 'selection_utilisateur' }
    },
    {
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [2.428, 46.538] },
      properties: { id: 'parcelle', source: 'cadastre', cid: '75127000A1142' }
    }
  ]
};

let map: MapRef | undefined;

function Probe() {
  const current = useMapLibre();
  useEffect(() => {
    map = current;
  }, [current]);
  return null;
}

function layerIds() {
  return map!.getStyle().layers.map((layer) => layer.id);
}

function expectLayerOrder() {
  const ids = layerIds();
  const position = (id: string) => {
    expect(ids, id).toContain(id);
    return ids.indexOf(id);
  };
  // The highlight sits where the cadastre style puts it, under the sections;
  // the selections of the usager sit above everything.
  expect(position('parcelle-highlighted')).toBeLessThan(position('sections'));
  expect(position('sections')).toBeLessThan(position(ANCHORS.optionalLayers));
  expect(position(ANCHORS.optionalLayers)).toBeLessThan(
    position('selections-polygon')
  );
  expect(position('selections-polygon')).toBeLessThan(
    position(ANCHORS.selections)
  );
}

suite('MapCanvas', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    container = document.createElement('div');
    container.style.width = '800px';
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(() => {
    root.unmount();
    container.remove();
    map = undefined;
  });

  test('keeps the layers in order through a change of basemap', async () => {
    root.render(
      <MapReader featureCollection={featureCollection}>
        <MapCanvas layers={['cadastres']} />
        <Probe />
      </MapReader>
    );

    await vi.waitFor(expectLayerOrder, { timeout: 10000 });
    expect(map!.getFilter('parcelle-highlighted')).toEqual([
      'in',
      ['get', 'id'],
      ['literal', ['75127000A1142']]
    ]);

    await page
      .getByRole('button', { name: 'Sélectionner les couches cartographiques' })
      .click();
    await page.getByText('Vectoriel').click();

    await vi.waitFor(() => expect(map!.getStyle().name).toBe('Carte OSM'), {
      timeout: 10000
    });
    await vi.waitFor(expectLayerOrder, { timeout: 10000 });
  });
});
