import type { Geometry, Position } from 'geojson';
import { LngLatBounds } from 'maplibre-gl';

type Coordinates = Position | Coordinates[];

export function getBounds(geometry: Geometry): LngLatBounds {
  const bounds = new LngLatBounds();
  extendBounds(bounds, geometry);
  return bounds;
}

function extendBounds(bounds: LngLatBounds, geometry: Geometry) {
  if (geometry.type == 'GeometryCollection') {
    for (const child of geometry.geometries) {
      extendBounds(bounds, child);
    }
  } else {
    extendBoundsWithCoordinates(bounds, geometry.coordinates);
  }
}

function extendBoundsWithCoordinates(
  bounds: LngLatBounds,
  coordinates: Coordinates
) {
  if (isPosition(coordinates)) {
    bounds.extend([coordinates[0], coordinates[1]]);
  } else {
    for (const child of coordinates) {
      extendBoundsWithCoordinates(bounds, child);
    }
  }
}

function isPosition(coordinates: Coordinates): coordinates is Position {
  return typeof coordinates[0] == 'number';
}
