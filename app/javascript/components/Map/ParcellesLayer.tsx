import { Layer } from '@vis.gl/react-maplibre';

import { useFeatures } from './FeatureCollectionProvider';

export type ParcellesSource = 'cadastre' | 'rpg';

// Parcelles are not drawn from their own geometry: the ones of the dossier are
// picked, by their id, among the parcelles of the vector tiles.
export function ParcellesLayer({ source }: { source: ParcellesSource }) {
  const features = useFeatures(source);
  const property = source == 'rpg' ? 'ID_PARCEL' : 'id';
  const ids = features.map((feature) => feature.properties?.cid);

  return (
    <Layer
      id="parcelles-selected"
      type="fill"
      source={source}
      source-layer="parcelles"
      filter={['in', ['get', property], ['literal', ids]]}
      paint={{ 'fill-color': 'rgba(1, 129, 0, 1)', 'fill-opacity': 0.7 }}
    />
  );
}
