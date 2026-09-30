import type { FeatureCollection } from 'geojson';

import { MapLibre } from '../shared/maplibre/MapLibre';
import { ParcelleLayer } from './components/ParcelleLayer';
import { GeoJSONLayer } from './components/GeoJSONLayer';
import { getParcelleLayer, PARCELLE_LAYERS } from '../shared/maplibre/styles';

const MapReader = ({
  featureCollection,
  options
}: {
  featureCollection: FeatureCollection;
  options: { layers: string[] };
}) => {
  const parcelleLayer = getParcelleLayer(options.layers);
  const source = parcelleLayer && PARCELLE_LAYERS[parcelleLayer].source;
  return (
    <MapLibre layers={options.layers}>
      <GeoJSONLayer featureCollection={featureCollection} />
      {source ? (
        <ParcelleLayer source={source} featureCollection={featureCollection} />
      ) : null}
    </MapLibre>
  );
};

export default MapReader;
