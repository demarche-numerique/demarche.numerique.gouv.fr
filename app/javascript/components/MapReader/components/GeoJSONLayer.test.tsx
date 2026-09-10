import { vi, suite, test, expect, beforeEach, afterEach } from 'vitest';
import { createRoot, type Root } from 'react-dom/client';
import { Popup } from 'maplibre-gl';
import type { FeatureCollection } from 'geojson';

import type { EventHandler } from '../../shared/maplibre/hooks';
import { GeoJSONLayer } from './GeoJSONLayer';

type Handler = (...args: unknown[]) => void;

const layerHandlers = new Map<string, Handler>();

const fakeMap = {
  on(event: string, target: string | Handler, callback?: Handler) {
    if (typeof target == 'string' && callback) {
      layerHandlers.set(`${event}:${target}`, callback);
    }
  },
  off() {},
  getSource: () => undefined,
  addSource() {
    return fakeMap;
  },
  addLayer() {
    return fakeMap;
  },
  getCanvas: () => ({ style: {} }),
  fitBounds() {},
  flyTo() {}
};

vi.mock('../../shared/maplibre/MapLibre', () => ({
  useMapLibre: () => fakeMap
}));

// The popup is only rendered on a real map; keep its content in the test page
// instead so we can inspect what the description turned into.
let popupContent: HTMLElement | undefined;
vi.spyOn(Popup.prototype, 'addTo').mockImplementation(function (this: Popup) {
  popupContent = this._content;
  document.body.appendChild(popupContent);
  return this;
});

declare global {
  interface Window {
    markupEvaluated?: boolean;
  }
}

const payload = '<img src="x" onerror="window.markupEvaluated = true">';

const featureCollection: FeatureCollection = {
  type: 'FeatureCollection',
  bbox: [2.35, 48.85, 2.35, 48.85],
  features: [
    {
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [2.35, 48.85] },
      properties: {
        id: 'point',
        source: 'selection_utilisateur',
        description: payload
      }
    }
  ]
};

suite('GeoJSONLayer', () => {
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
    popupContent?.remove();
    popupContent = undefined;
    delete window.markupEvaluated;
  });

  test('shows the description of a hovered feature as plain text', async () => {
    root.render(<GeoJSONLayer featureCollection={featureCollection} />);

    const onMouseEnter = await vi.waitFor(() => {
      const handler = layerHandlers.get('mouseenter:point-layer');
      expect(handler).toBeDefined();
      return handler as EventHandler;
    });

    onMouseEnter({
      features: featureCollection.features,
      lngLat: { lng: 2.35, lat: 48.85 }
    } as Parameters<EventHandler>[0]);

    // Give a broken image the time to fire its error handler.
    await new Promise((resolve) => setTimeout(resolve, 200));
    expect(window.markupEvaluated).toBeUndefined();

    expect(popupContent?.querySelector('img')).toBeNull();
    expect(popupContent?.textContent).toBe(payload);
  });
});
