import { useMemo } from 'react';
import { Layer, Source } from '@vis.gl/react-maplibre';

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
export function OptionalLayers({ layers }: { layers: LayersMap }) {
  const enabled = useMemo(
    () => Object.keys(layers).filter((id) => layers[id].enabled),
    [layers]
  );
  const highlighted = useHighlightedParcelles(enabled);
  const { sources, specifications } = useMemo(() => {
    const opacity = Object.fromEntries(
      enabled.map((id) => [id, layers[id].opacity])
    );
    return {
      sources: Object.entries(buildOptionalSources(enabled)),
      specifications: buildOptionalLayers(enabled, opacity, highlighted)
    };
  }, [layers, enabled, highlighted]);

  return (
    <>
      {sources.map(([id, source]) => (
        <Source key={id} id={id} {...source} />
      ))}
      {specifications.map((layer) => (
        <Layer key={layer.id} {...layer} beforeId={ANCHORS.optionalLayers} />
      ))}
    </>
  );
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
