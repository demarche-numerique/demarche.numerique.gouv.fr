import type { Geometry } from 'geojson';
import type { LngLatBounds, Map } from 'maplibre-gl';

import { getBounds } from './geometry';

// Fitting the map to a small shape, let alone to a point, ends up so close
// that nothing of the surroundings is left to tell where it is.
const MAX_ZOOM = 18;
const MAX_ZOOM_POINT = 17;

export function getMaxZoom(bounds: LngLatBounds): number {
  const isPoint =
    bounds.getWest() == bounds.getEast() &&
    bounds.getSouth() == bounds.getNorth();
  return isPoint ? MAX_ZOOM_POINT : MAX_ZOOM;
}

export function fitGeometry(
  map: Pick<Map, 'getContainer' | 'fitBounds'>,
  geometry: Geometry
) {
  const bounds = getBounds(geometry);
  const { clientWidth, clientHeight } = map.getContainer();

  map.fitBounds(bounds, {
    // The shape takes half of the map at most, whatever the size of the map.
    padding: {
      top: clientHeight / 4,
      bottom: clientHeight / 4,
      left: clientWidth / 4,
      right: clientWidth / 4
    },
    maxZoom: getMaxZoom(bounds)
  });
}
