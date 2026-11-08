import type { ReactNode } from 'react';
import type { FeatureCollection } from 'geojson';

import { MapLibreProvider } from './MapLibreProvider';
import { ReadableFeatureCollectionProvider } from './FeatureCollectionProvider';

export function MapReader({
  featureCollection,
  children
}: {
  featureCollection: FeatureCollection;
  children: ReactNode;
}) {
  return (
    <MapLibreProvider>
      <ReadableFeatureCollectionProvider featureCollection={featureCollection}>
        {children}
      </ReadableFeatureCollectionProvider>
    </MapLibreProvider>
  );
}
