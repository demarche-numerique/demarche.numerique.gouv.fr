import { useMemo } from 'react';
import { Layer, Source } from '@vis.gl/react-maplibre';
import type { Feature, FeatureCollection } from 'geojson';
import type { ExpressionSpecification, FilterSpecification } from 'maplibre-gl';

import { ANCHORS } from '../shared/maplibre/styles';
import { useFeatures } from './FeatureCollectionProvider';

const SOURCE = 'selection_utilisateur';

export const SELECTIONS_LAYERS = [
  'selections-polygon',
  'selections-line',
  'selections-point'
];

// The shapes of the usager. In the editor, Terra Draw draws those it holds:
// they stay here, marked `hidden`, only to be hovered.
export function SelectionsLayer({ features }: { features?: Feature[] }) {
  const selections = useFeatures(SOURCE);
  const data = useMemo<FeatureCollection>(
    () => ({
      type: 'FeatureCollection',
      features: (features ?? selections).filter(
        (feature) => feature.properties?.source == SOURCE
      )
    }),
    [features, selections]
  );

  return (
    <Source id="selections" type="geojson" data={data}>
      <Layer
        id="selections-polygon-outline"
        type="line"
        beforeId={ANCHORS.selections}
        filter={geometryType('Polygon')}
        paint={{
          'line-color': 'rgba(255, 0, 0, 1)',
          'line-width': 4,
          'line-opacity': visible(1)
        }}
      />
      <Layer
        id="selections-polygon"
        type="fill"
        beforeId={ANCHORS.selections}
        filter={geometryType('Polygon')}
        paint={{ 'fill-color': '#EC3323', 'fill-opacity': visible(0.5) }}
      />
      <Layer
        id="selections-line"
        type="line"
        beforeId={ANCHORS.selections}
        filter={geometryType('LineString')}
        paint={{
          'line-color': 'rgba(55, 42, 127, 1.00)',
          'line-width': 3,
          'line-opacity': visible(1)
        }}
      />
      <Layer
        id="selections-point"
        type="circle"
        beforeId={ANCHORS.selections}
        filter={geometryType('Point')}
        paint={{ 'circle-color': '#EC3323', 'circle-opacity': visible(1) }}
      />
    </Source>
  );
}

function visible(opacity: number): ExpressionSpecification {
  return ['case', ['==', ['get', 'hidden'], true], 0, opacity];
}

function geometryType(
  type: 'Polygon' | 'LineString' | 'Point'
): FilterSpecification {
  return ['in', ['geometry-type'], ['literal', [type, `Multi${type}`]]];
}
