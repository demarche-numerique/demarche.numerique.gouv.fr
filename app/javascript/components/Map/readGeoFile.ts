import { gpx, kml } from '@tmcw/togeojson';
import type { FeatureCollection, Feature, Geometry } from 'geojson';

import { generateId } from '../shared/maplibre/utils';

export function readGeoFile(
  file: File
): Promise<FeatureCollection & { filename: string }> {
  const reader = new FileReader();
  return new Promise((resolve, reject) => {
    reader.onload = (event: FileReaderEventMap['load']) => {
      const content = event.target?.result;
      if (typeof content == 'string') {
        const featureCollection = parse(content, file.name);
        resolve(normalizeFeatureCollection(featureCollection, file.name));
      } else {
        reject(new Error('Invalid file content'));
      }
    };
    reader.readAsText(file, 'UTF-8');
  });
}

function parse(
  content: string,
  filename: string
): FeatureCollection<Geometry | null> {
  const isGpxFile = filename.includes('.gpx');
  const xml = new DOMParser().parseFromString(content, 'text/xml');
  return isGpxFile ? gpx(xml) : kml(xml);
}

function normalizeFeatureCollection(
  featureCollection: FeatureCollection<Geometry | null>,
  filename: string
): FeatureCollection & { filename: string } {
  const sourceFilename = `${generateId()}-${filename}`;
  const features = featureCollection.features
    .filter(isFeatureWithGeometry)
    .flatMap((feature) => normalizeFeature(feature, sourceFilename));

  return {
    type: 'FeatureCollection',
    features,
    filename: sourceFilename
  };
}

function isFeatureWithGeometry(
  feature: Feature<Geometry | null>
): feature is Feature {
  return feature.geometry !== null;
}

function normalizeFeature(feature: Feature, filename?: string): Feature[] {
  switch (feature.geometry.type) {
    case 'MultiPoint':
      return feature.geometry.coordinates.map((coordinates) => ({
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates
        },
        properties: { ...feature.properties, filename }
      }));
    case 'MultiLineString':
      return feature.geometry.coordinates.map((coordinates) => ({
        type: 'Feature',
        geometry: {
          type: 'LineString',
          coordinates
        },
        properties: { ...feature.properties, filename }
      }));
    case 'MultiPolygon':
      return feature.geometry.coordinates.map((coordinates) => ({
        type: 'Feature',
        geometry: {
          type: 'Polygon',
          coordinates
        },
        properties: { ...feature.properties, filename }
      }));
    case 'GeometryCollection':
      return feature.geometry.geometries.map((geometry) => ({
        type: 'Feature',
        geometry,
        properties: { ...feature.properties, filename }
      }));
    default:
      return [
        {
          ...feature,
          properties: { ...feature.properties, filename }
        }
      ];
  }
}
