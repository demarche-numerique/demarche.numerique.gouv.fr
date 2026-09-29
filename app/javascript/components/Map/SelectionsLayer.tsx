import { Layer, Source } from '@vis.gl/react-maplibre';
import type { FilterSpecification } from 'maplibre-gl';

import { useFeatures } from './FeatureCollectionProvider';

const SOURCE = 'selection_utilisateur';

export const SELECTIONS_LAYERS = [
  'selections-polygon',
  'selections-line',
  'selections-point'
];

export function SelectionsLayer() {
  const features = useFeatures(SOURCE);

  return (
    <Source
      id="selections"
      type="geojson"
      data={{ type: 'FeatureCollection', features }}
    >
      <Layer
        id="selections-polygon-outline"
        type="line"
        filter={geometryType('Polygon')}
        paint={{ 'line-color': 'rgba(255, 0, 0, 1)', 'line-width': 4 }}
      />
      <Layer
        id="selections-polygon"
        type="fill"
        filter={geometryType('Polygon')}
        paint={{ 'fill-color': '#EC3323', 'fill-opacity': 0.5 }}
      />
      <Layer
        id="selections-line"
        type="line"
        filter={geometryType('LineString')}
        paint={{ 'line-color': 'rgba(55, 42, 127, 1.00)', 'line-width': 3 }}
      />
      <Layer
        id="selections-point"
        type="circle"
        filter={geometryType('Point')}
        paint={{ 'circle-color': '#EC3323' }}
      />
    </Source>
  );
}

function geometryType(
  type: 'Polygon' | 'LineString' | 'Point'
): FilterSpecification {
  return ['in', ['geometry-type'], ['literal', [type, `Multi${type}`]]];
}
