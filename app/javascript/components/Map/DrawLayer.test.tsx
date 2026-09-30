import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { page, userEvent } from 'vitest/browser';
import { createRoot, type Root } from 'react-dom/client';
import { useEffect, useState } from 'react';
import type { MapRef } from '@vis.gl/react-maplibre';
import type { GeoJSONSource } from 'maplibre-gl';
import type { Feature, FeatureCollection } from 'geojson';

import { MapReader } from './MapReader';
import { MapCanvas } from './MapCanvas';
import { DrawLayer } from './DrawLayer';
import { useMapLibre } from './MapLibreProvider';

vi.mock('@lingui/react/macro', () => ({
  useLingui: () => ({
    t: (s: TemplateStringsArray | string) => String(s),
    i18n: { locale: 'fr' }
  }),
  Trans: ({ children }: { children: React.ReactNode }) => children
}));

// No tile ever loads here: the drawing is what is under test, not the tiles.
vi.stubGlobal('fetch', () => Promise.reject(new Error('offline')));
vi.spyOn(console, 'error').mockImplementation(() => {});

// Firefox on the CI runner has no WebGL2: no map ever mounts there.
const webgl2 = document.createElement('canvas').getContext('webgl2') != null;

const BBOX: [number, number, number, number] = [2.42, 46.53, 2.44, 46.55];

const existing: Feature = {
  type: 'Feature',
  id: 'existing',
  geometry: { type: 'Point', coordinates: [2.425, 46.535] },
  properties: { source: 'selection_utilisateur' }
};

let map: MapRef | undefined;
let events: [string, ...unknown[]][] = [];
let setFeatures: (features: Feature[]) => void;

function Probe() {
  const current = useMapLibre();
  useEffect(() => {
    map = current;
  }, [current]);
  return null;
}

function Editor() {
  const [features, set] = useState<Feature[]>([existing]);
  useEffect(() => {
    setFeatures = set;
  }, []);
  const featureCollection: FeatureCollection = {
    type: 'FeatureCollection',
    bbox: BBOX,
    features
  };

  return (
    <MapReader featureCollection={featureCollection}>
      <MapCanvas layers={[]}>
        <DrawLayer
          features={features}
          onCreate={(feature) => {
            events.push(['create', feature]);
            set((features) => [
              ...features,
              { ...feature, properties: { source: 'selection_utilisateur' } }
            ]);
          }}
          onUpdate={(id, geometry) => events.push(['update', id, geometry])}
          onDelete={(id) => {
            events.push(['delete', id]);
            set((features) => features.filter((feature) => feature.id != id));
          }}
        />
      </MapCanvas>
      <Probe />
    </MapReader>
  );
}

async function drawnIds(type: 'point' | 'polygon') {
  const source = map!.getSource(`td-${type}`) as GeoJSONSource | undefined;
  if (!source) {
    return undefined;
  }
  const data = (await source.getData()) as FeatureCollection;
  return data.features
    .filter((feature) => feature.properties?.mode != 'select')
    .map((feature) => feature.id);
}

// Clicks the canvas at a position of the map.
async function clickAt(lng: number, lat: number) {
  const { x, y } = map!.project([lng, lat]);
  await page
    .elementLocator(map!.getCanvas())
    .click({ position: { x: Math.round(x), y: Math.round(y) } });
}

function tool(name: string) {
  return page.getByRole('button', { name });
}

suite('DrawLayer', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(async () => {
    // The clicks must land inside the viewport.
    await page.viewport(1024, 768);
    container = document.createElement('div');
    container.style.width = '800px';
    document.body.appendChild(container);
    root = createRoot(container);
    events = [];
  });

  afterEach(() => {
    root.unmount();
    container.remove();
    map = undefined;
  });

  test.skipIf(!webgl2)(
    'draws a polygon, keeps it through a change of basemap and deletes it',
    async () => {
      root.render(<Editor />);

      await vi.waitFor(
        async () => expect(await drawnIds('point')).toEqual(['existing']),
        { timeout: 10000 }
      );

      await tool('Dessiner un polygone').click();
      await expect
        .element(tool('Dessiner un polygone'))
        .toHaveAttribute('aria-pressed', 'true');
      await clickAt(2.426, 46.536);
      await clickAt(2.434, 46.536);
      await clickAt(2.43, 46.544);
      await userEvent.keyboard('{Enter}');

      await vi.waitFor(() => expect(events).toHaveLength(1));
      const [type, feature] = events[0] as [string, Feature];
      expect(type).toBe('create');
      expect(feature.id).toMatch(/^[0-9a-f-]{36}$/);
      expect(feature.geometry.type).toBe('Polygon');
      await expect
        .element(tool('Sélectionner et modifier une forme'))
        .toHaveAttribute('aria-pressed', 'true');
      await vi.waitFor(async () =>
        expect(await drawnIds('polygon')).toEqual([feature.id])
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
      await userEvent.keyboard('{Escape}');

      await vi.waitFor(
        async () => {
          expect(await drawnIds('polygon')).toEqual([feature.id]);
          expect(await drawnIds('point')).toEqual(['existing']);
        },
        { timeout: 10000 }
      );
      const layers = map!.getStyle().layers.map((layer) => layer.id);
      expect(layers.indexOf('td-polygon')).toBeLessThan(
        layers.indexOf('anchor-selections')
      );

      await expect
        .element(tool('Supprimer la forme sélectionnée'))
        .toBeDisabled();
      await clickAt(2.43, 46.539);
      await tool('Supprimer la forme sélectionnée').click();

      await vi.waitFor(() =>
        expect(events.at(-1)).toEqual(['delete', feature.id])
      );
      await vi.waitFor(async () =>
        expect(await drawnIds('polygon')).toEqual([])
      );
    }
  );

  test.skipIf(!webgl2)(
    'follows the features it is given without reporting them back',
    async () => {
      root.render(<Editor />);
      await vi.waitFor(
        async () => expect(await drawnIds('point')).toEqual(['existing']),
        { timeout: 10000 }
      );

      setFeatures([
        {
          ...existing,
          geometry: { type: 'Point', coordinates: [2.43, 46.54] }
        }
      ]);
      await vi.waitFor(async () => {
        const source = map!.getSource('td-point') as GeoJSONSource;
        const data = (await source.getData()) as FeatureCollection;
        expect(data.features[0].geometry).toEqual({
          type: 'Point',
          coordinates: [2.43, 46.54]
        });
      });

      setFeatures([]);
      await vi.waitFor(async () => expect(await drawnIds('point')).toEqual([]));
      expect(events).toEqual([]);
    }
  );
});
