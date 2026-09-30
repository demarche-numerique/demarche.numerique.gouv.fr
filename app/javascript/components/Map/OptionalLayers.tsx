import { useMemo } from 'react';
import { Layer, Source } from '@vis.gl/react-maplibre';
import type { LayerSpecification } from 'maplibre-gl';

import {
  ANCHORS,
  buildOptionalLayers,
  buildOptionalSources,
  getParcelleLayer,
  PARCELLE_LAYERS,
  type LayersMap
} from '../shared/maplibre/styles';
import { useFeatures } from './FeatureCollectionProvider';

// The optional layers of the procedure (protected areas, parcelles...), drawn
// above the basemap. A change of opacity only touches the paint property of
// the layer, and a layer toggled off is removed on its own.
//
// Each layer goes in before the next enabled one of its kind, so that a layer
// turned back on finds its place again and not the top. The rasters stay under
// the parcelle layers through an anchor of their own, not by going in before
// them: after a change of basemap the parcelle layers wait for their source.
export function OptionalLayers({ layers }: { layers: LayersMap }) {
  const enabled = useMemo(
    () => Object.keys(layers).filter((id) => layers[id].enabled),
    [layers]
  );
  const highlighted = useHighlightedParcelles(enabled);
  const { sources, rasters, parcelles } = useMemo(() => {
    const opacity = Object.fromEntries(
      enabled.map((id) => [id, layers[id].opacity])
    );
    const specifications = buildOptionalLayers(enabled, opacity, highlighted);
    return {
      sources: Object.entries(buildOptionalSources(enabled)),
      rasters: specifications.filter(({ type }) => type == 'raster'),
      parcelles: specifications.filter(({ type }) => type != 'raster')
    };
  }, [layers, enabled, highlighted]);

  return (
    <>
      {sources.map(([id, source]) => (
        <Source key={id} id={id} {...source} />
      ))}
      {chain(parcelles, ANCHORS.optionalLayers)}
      {chain(rasters, ANCHORS.rasters)}
    </>
  );
}

// The layers mount from the last to the first: the layer to go before is
// always there already.
function chain(layers: LayerSpecification[], anchor: string) {
  return layers
    .map((layer, index) => (
      <Layer
        key={layer.id}
        {...layer}
        beforeId={layers[index + 1]?.id ?? anchor}
      />
    ))
    .reverse();
}

// The parcelles of the dossier are not drawn: the parcelles of the tiles
// bearing their ids are highlighted.
function useHighlightedParcelles(enabled: string[]): string[] {
  const parcelleLayer = getParcelleLayer(enabled);
  const features = useFeatures(
    parcelleLayer ? PARCELLE_LAYERS[parcelleLayer].source : ''
  );
  return useMemo(
    () => features.map((feature) => feature.properties?.cid),
    [features]
  );
}
