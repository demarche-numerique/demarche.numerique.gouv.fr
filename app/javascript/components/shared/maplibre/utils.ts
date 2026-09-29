import type { Feature, FeatureCollection, Geometry } from 'geojson';
import type { LngLatBoundsLike } from 'maplibre-gl';
import { LngLatBounds } from 'maplibre-gl';
import invariant from 'tiny-invariant';

export function getBounds(geometry: Geometry): LngLatBoundsLike {
  const bbox = new LngLatBounds();

  if (geometry.type === 'Point') {
    return [geometry.coordinates, geometry.coordinates] as [
      [number, number],
      [number, number]
    ];
  } else if (geometry.type === 'LineString') {
    for (const coordinate of geometry.coordinates) {
      bbox.extend(coordinate as [number, number]);
    }
  } else {
    invariant(
      geometry.type != 'GeometryCollection',
      'GeometryCollection not supported'
    );
    for (const coordinate of geometry.coordinates[0]) {
      bbox.extend(coordinate as [number, number]);
    }
  }
  return bbox;
}

export function findFeature<G extends Geometry>(
  featureCollection: FeatureCollection<G>,
  value: unknown,
  property = 'id'
): Feature<G> | null {
  return (
    featureCollection.features.find(
      (feature) => feature.properties && feature.properties[property] === value
    ) ?? null
  );
}

export function filterFeatureCollection<G extends Geometry>(
  featureCollection: FeatureCollection<G>,
  source: string
): FeatureCollection<G> {
  return {
    type: 'FeatureCollection',
    features: featureCollection.features.filter(
      (feature) => feature.properties?.source === source
    )
  };
}

export function generateId(): string {
  return Math.random().toString(20).substring(2, 6);
}

export function getParcellesSource(layers: string[]) {
  if (layers.includes('cadastres')) {
    return 'cadastre';
  }
  if (layers.includes('rpg')) {
    return 'rpg';
  }
}
