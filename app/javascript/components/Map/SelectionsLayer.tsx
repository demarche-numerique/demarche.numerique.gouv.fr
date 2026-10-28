import { useMemo } from 'react';
import { Layer, Source } from '@vis.gl/react-maplibre';
import type { FeatureCollection } from 'geojson';
import type { FilterSpecification } from 'maplibre-gl';

import { ANCHORS } from '../shared/maplibre/styles';
import { useFeatures } from './FeatureCollectionProvider';

const SOURCE = 'selection_utilisateur';

export const SELECTIONS_LAYERS = [
  'selections-polygon',
  'selections-line',
  'selections-point'
];

export function SelectionsLayer() {
  const features = useFeatures(SOURCE);
  const data = useMemo<FeatureCollection>(
    () => ({ type: 'FeatureCollection', features }),
    [features]
  );

  return (
    <Source id="selections" type="geojson" data={data}>
      <Layer
        id="selections-polygon-outline"
        type="line"
        beforeId={ANCHORS.selections}
        filter={geometryType('Polygon')}
        paint={{ 'line-color': 'rgba(255, 0, 0, 1)', 'line-width': 4 }}
      />
      <Layer
        id="selections-polygon"
        type="fill"
        beforeId={ANCHORS.selections}
        filter={geometryType('Polygon')}
        paint={{ 'fill-color': '#EC3323', 'fill-opacity': 0.5 }}
      />
      <Layer
        id="selections-line"
        type="line"
        beforeId={ANCHORS.selections}
        filter={geometryType('LineString')}
        paint={{ 'line-color': 'rgba(55, 42, 127, 1.00)', 'line-width': 3 }}
      />
      <Layer
        id="selections-point"
        type="circle"
        beforeId={ANCHORS.selections}
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
