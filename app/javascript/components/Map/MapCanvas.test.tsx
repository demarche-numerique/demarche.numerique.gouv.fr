import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { page, userEvent } from 'vitest/browser';
import { createRoot, type Root } from 'react-dom/client';
import { useEffect } from 'react';
import type { MapRef } from '@vis.gl/react-maplibre';
import type { FeatureCollection } from 'geojson';

import { MapReader } from './MapReader';
import { MapCanvas } from './MapCanvas';
import { useMapLibre } from './MapLibreProvider';
import { ANCHORS } from '../shared/maplibre/styles';

vi.mock('@lingui/react/macro', () => ({
  useLingui: () => ({
    t: (s: TemplateStringsArray | string) => String(s),
    i18n: { locale: 'fr' }
  }),
  Trans: ({ children }: { children: React.ReactNode }) => children
}));

// No tile ever loads here: the layers are what is under test, not the tiles.
// The map reports every failed request on the console: keep it quiet.
vi.stubGlobal('fetch', () => Promise.reject(new Error('offline')));
const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

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
      properties: {
        id: 'shape',
        source: 'selection_utilisateur',
        description: 'Un jardin'
      }
    },
    {
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [2.428, 46.538] },
      properties: { id: 'parcelle', source: 'cadastre', cid: '75127000A1142' }
    }
  ]
};

// Firefox on the CI runner has no WebGL2: the canvas shows its banner there
// and no map ever mounts.
const webgl2 = document.createElement('canvas').getContext('webgl2') != null;

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
  // The highlight sits where the cadastre style puts it, under the labels and
  // the sections; the selections of the usager sit above everything.
  expect(position('parcelle-highlighted')).toBeLessThan(
    position('parcelles-labels')
  );
  expect(position('parcelles-labels')).toBeLessThan(position('sections'));
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
    consoleError.mockClear();
  });

  afterEach(() => {
    root.unmount();
    container.remove();
    map = undefined;
  });

  test.skipIf(!webgl2)(
    'keeps the layers in order through a change of basemap',
    async () => {
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
        .getByRole('button', {
          name: 'Sélectionner les couches cartographiques'
        })
        .click();
      await page.getByText('Vectoriel').click();

      await vi.waitFor(() => expect(map!.getStyle().name).toBe('Carte OSM'), {
        timeout: 10000
      });
      await vi.waitFor(expectLayerOrder, { timeout: 10000 });
    }
  );

  test.skipIf(!webgl2)(
    'puts a layer turned back on where it was, under the parcelles',
    async () => {
      root.render(
        <MapReader featureCollection={featureCollection}>
          <MapCanvas layers={['unesco', 'cadastres']} />
          <Probe />
        </MapReader>
      );
      const below = (id: string, other: string) => {
        const ids = layerIds();
        expect(ids, id).toContain(id);
        expect(ids.indexOf(id), `${id} under ${other}`).toBeLessThan(
          ids.indexOf(other)
        );
      };
      await vi.waitFor(() => below('patrinat_bios', 'batiments-line'), {
        timeout: 10000
      });

      await page
        .getByRole('button', {
          name: 'Sélectionner les couches cartographiques'
        })
        .click();
      const unesco = page.getByRole('checkbox', { name: 'UNESCO' });
      await unesco.click();
      await vi.waitFor(() => expect(layerIds()).not.toContain('patrinat_bios'));
      await unesco.click();

      await vi.waitFor(() => {
        below('patrinat_geoparc', 'patrinat_bios');
        below('patrinat_bios', 'batiments-line');
      });
      expectLayerOrder();
    }
  );

  test.skipIf(!webgl2)(
    'brings the rasters back after a change of basemap without waiting for the parcelles',
    async () => {
      root.render(
        <MapReader featureCollection={featureCollection}>
          <MapCanvas layers={['unesco', 'cadastres']} />
          <Probe />
        </MapReader>
      );
      const expectLayers = () => {
        expect(layerIds()).toContain('patrinat_bios');
        expect(layerIds()).toContain('sections');
      };
      await vi.waitFor(expectLayers, { timeout: 10000 });

      await page
        .getByRole('button', {
          name: 'Sélectionner les couches cartographiques'
        })
        .click();
      await page.getByText('Vectoriel').click();
      await vi.waitFor(() => expect(map!.getStyle().name).toBe('Carte OSM'), {
        timeout: 10000
      });
      await vi.waitFor(expectLayers, { timeout: 10000 });

      // A layer inserted before one that is not there yet is refused.
      const refused = consoleError.mock.calls
        .map(([error]) => String(error?.message ?? error))
        .filter((message) => message.includes('Cannot add layer'));
      expect(refused).toEqual([]);
      expectLayerOrder();
    }
  );

  test.skipIf(!webgl2)(
    'drops the popup when the mouse leaves the map over a shape',
    async () => {
      await page.viewport(1024, 768);
      const outside = document.createElement('p');
      outside.textContent = 'Hors de la carte';
      document.body.appendChild(outside);
      root.render(
        <MapReader featureCollection={featureCollection}>
          <MapCanvas layers={[]} />
          <Probe />
        </MapReader>
      );
      await vi.waitFor(
        () => expect(layerIds()).toContain('selections-polygon'),
        { timeout: 10000 }
      );
      // Close enough for the shape to cover the whole map.
      map!.jumpTo({ center: [2.42867, 46.53833], zoom: 21 });
      const canvas = page.elementLocator(map!.getCanvas());
      const popup = () => document.querySelector('.maplibregl-popup');

      try {
        let x = 400;
        await vi.waitFor(
          async () => {
            await userEvent.hover(canvas, { position: { x: x++, y: 490 } });
            expect(popup()).not.toBeNull();
          },
          { timeout: 10000 }
        );
        await userEvent.hover(page.elementLocator(outside));

        await vi.waitFor(() => expect(popup()).toBeNull());
      } finally {
        outside.remove();
      }
    }
  );
});
