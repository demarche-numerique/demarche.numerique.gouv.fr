import type {
  Feature,
  Geometry,
  LineString,
  Point,
  Polygon,
  Position
} from 'geojson';
import type { GeoJSONStoreFeatures } from 'terra-draw';

// About ten centimetres: finer than any shape an usager draws by hand, and
// what Terra Draw requires of every coordinate it is given.
export const COORDINATE_PRECISION = 6;

export type DrawableGeometry = Point | LineString | Polygon;

const MODES = {
  Point: 'point',
  LineString: 'linestring',
  Polygon: 'polygon'
} as const;

export function isDrawable(
  feature: Feature
): feature is Feature<DrawableGeometry> & { id: string } {
  return (
    typeof feature.id == 'string' &&
    feature.properties?.source == 'selection_utilisateur' &&
    feature.geometry != null &&
    feature.geometry.type in MODES
  );
}

export function roundGeometry<G extends DrawableGeometry>(geometry: G): G {
  switch (geometry.type) {
    case 'Point':
      return { ...geometry, coordinates: roundPosition(geometry.coordinates) };
    case 'LineString':
      return {
        ...geometry,
        coordinates: geometry.coordinates.map(roundPosition)
      };
    case 'Polygon':
      return {
        ...geometry,
        coordinates: geometry.coordinates.map((ring) => ring.map(roundPosition))
      };
  }
}

function roundPosition([lng, lat]: Position): Position {
  const factor = 10 ** COORDINATE_PRECISION;
  return [Math.round(lng * factor) / factor, Math.round(lat * factor) / factor];
}

export function toDrawFeature(
  id: string,
  geometry: DrawableGeometry
): GeoJSONStoreFeatures {
  return {
    id,
    type: 'Feature',
    geometry: roundGeometry(geometry),
    properties: { mode: MODES[geometry.type] }
  };
}

// What to tell Terra Draw so that it shows `features`, given the geometries it
// holds (keyed by id, as serialized by `serializeGeometry`).
export function planSync(
  drawn: ReadonlyMap<string, string>,
  features: (Feature<DrawableGeometry> & { id: string })[]
) {
  const add: GeoJSONStoreFeatures[] = [];
  const update: [string, DrawableGeometry][] = [];
  const ids = new Set<string>();

  for (const { id, geometry } of features) {
    ids.add(id);
    const rounded = roundGeometry(geometry);
    const serialized = serializeGeometry(rounded);
    if (!drawn.has(id)) {
      add.push(toDrawFeature(id, rounded));
    } else if (drawn.get(id) != serialized) {
      update.push([id, rounded]);
    }
  }
  const remove = [...drawn.keys()].filter((id) => !ids.has(id));

  return { add, update, remove };
}

export function serializeGeometry(geometry: Geometry) {
  return JSON.stringify(geometry);
}
