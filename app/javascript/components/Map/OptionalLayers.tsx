import { useMemo } from 'react';
import { Layer, Source } from '@vis.gl/react-maplibre';

import {
  buildOptionalLayers,
  buildOptionalSources,
  type LayersMap
} from '../shared/maplibre/styles';

// The optional layers of the procedure (protected areas, parcelles...), drawn
// above the basemap. A change of opacity only touches the paint property of
// the layer, and a layer toggled off is removed on its own.
export function OptionalLayers({ layers }: { layers: LayersMap }) {
  const { sources, specifications } = useMemo(() => {
    const enabled = Object.entries(layers).filter(([, { enabled }]) => enabled);
    const ids = enabled.map(([id]) => id);
    const opacity = Object.fromEntries(
      enabled.map(([id, { opacity }]) => [id, opacity])
    );
    return {
      sources: Object.entries(buildOptionalSources(ids)),
      specifications: buildOptionalLayers(ids, opacity)
    };
  }, [layers]);

  return (
    <>
      {sources.map(([id, source]) => (
        <Source key={id} id={id} {...source} />
      ))}
      {specifications.map((layer) => (
        <Layer key={layer.id} {...layer} />
      ))}
    </>
  );
}
