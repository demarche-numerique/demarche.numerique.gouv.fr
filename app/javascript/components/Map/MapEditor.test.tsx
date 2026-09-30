import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { page } from 'vitest/browser';
import { createRoot, type Root } from 'react-dom/client';
import { useEffect } from 'react';
import type { MapRef } from '@vis.gl/react-maplibre';
import type { GeoJSONSource } from 'maplibre-gl';
import type { FeatureCollection } from 'geojson';

import { MapEditor } from './MapEditor';
import { MapCanvas } from './MapCanvas';
import { useMapLibre } from './MapLibreProvider';

vi.mock('@lingui/react/macro', () => ({
  useLingui: () => ({
    t: (s: TemplateStringsArray | string) => String(s),
    i18n: { locale: 'fr' }
  }),
  Trans: ({ children }: { children: React.ReactNode }) => children
}));

// No tile ever loads here: the drawing layers are what is under test.
vi.stubGlobal('fetch', () => Promise.reject(new Error('offline')));
vi.spyOn(console, 'error').mockImplementation(() => {});

// Firefox on the CI runner has no WebGL2: no map ever mounts there.
const webgl2 = document.createElement('canvas').getContext('webgl2') != null;

const featureCollection: FeatureCollection = {
  type: 'FeatureCollection',
  bbox: [2.42, 46.53, 2.44, 46.55],
  features: [
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [
          [
            [2.425, 46.535],
            [2.435, 46.535],
            [2.43, 46.545],
            [2.425, 46.535]
          ]
        ]
      },
      properties: { id: 'shape', source: 'selection_utilisateur' }
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

async function drawnIds() {
  const source = map!.getSource('td-polygon') as GeoJSONSource | undefined;
  if (!source) {
    return undefined;
  }
  const data = (await source.getData()) as FeatureCollection;
  return data.features.map((feature) => feature.id);
}

suite('MapEditor', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(async () => {
    await page.viewport(1024, 768);
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

  test.skipIf(!webgl2)(
    'keeps the shapes of the usager through a change of basemap',
    async () => {
      root.render(
        <MapEditor featureCollection={featureCollection} name="value">
          <MapCanvas layers={[]} />
          <Probe />
        </MapEditor>
      );
      await vi.waitFor(
        async () => expect(await drawnIds()).toEqual(['shape']),
        {
          timeout: 10000
        }
      );

      await page
        .getByRole('button', {
          name: 'Sélectionner les couches cartographiques'
        })
        .click();
      await page.getByText('Vectoriel').click();
      await vi.waitFor(() => expect(map!.getStyle().name).toBe('Carte OSM'), {
        timeout: 10000
      });

      await vi.waitFor(
        async () => expect(await drawnIds()).toEqual(['shape']),
        {
          timeout: 10000
        }
      );
    }
  );
});
