import { useMemo, useState } from 'react';
import type { Feature } from 'geojson';
import type { MapGeoJSONFeature } from 'maplibre-gl';

import {
  getParcelleLayer,
  PARCELLE_LAYERS,
  type LayersMap
} from '../shared/maplibre/styles';
import {
  useFeatureActions,
  useFeatureCollection,
  useHistory
} from './FeatureCollectionProvider';
import { DrawLayer } from './DrawLayer';
import { SelectionsLayer } from './SelectionsLayer';
import { isDrawable } from './draw';

// The layers of the editor: Terra Draw holds the shapes of the usager, and
// the selections layer shows what it cannot hold. The others stay in the
// selections layer, hidden, for their description to show on hover.
export function EditLayers({ layers }: { layers: LayersMap }) {
  const { features } = useFeatureCollection();
  const actions = useFeatureActions();
  const history = useHistory();
  const [refused, setRefused] = useState<string[]>([]);
  const parcelleLayer = getParcelleLayer(Object.keys(layers));
  const selections = useMemo(
    () =>
      features.map((feature) =>
        isDrawable(feature) && !refused.includes(feature.id)
          ? { ...feature, properties: { ...feature.properties, hidden: true } }
          : feature
      ),
    [features, refused]
  );

  if (!actions) {
    return null;
  }

  // A click on a parcelle of the tiles selects it, a second one deselects it.
  const toggleParcelle = (parcelle: MapGeoJSONFeature) => {
    if (!parcelleLayer) {
      return;
    }
    const { source, idProperty } = PARCELLE_LAYERS[parcelleLayer];
    const cid = String(parcelle.properties[idProperty]);
    const selected = features.find(
      (feature) =>
        feature.properties?.source == source && feature.properties?.cid == cid
    );
    if (selected) {
      actions.remove([String(selected.id)]);
    } else {
      const feature: Feature = {
        type: 'Feature',
        geometry: parcelle.geometry,
        properties: { ...parcelle.properties, source, cid }
      };
      actions.create([feature]);
    }
  };

  return (
    <>
      <SelectionsLayer features={selections} />
      <DrawLayer
        features={features}
        onCreate={(feature) => actions.create([feature])}
        onUpdate={(id, geometry) => actions.update(id, { geometry })}
        onDelete={(id) => actions.remove([id])}
        onRefuse={setRefused}
        onParcelleClick={parcelleLayer ? toggleParcelle : undefined}
        history={history ?? undefined}
      />
    </>
  );
}
