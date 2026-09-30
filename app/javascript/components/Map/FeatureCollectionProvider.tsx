import { createContext, useContext, useMemo, type ReactNode } from 'react';
import type { Feature, FeatureCollection } from 'geojson';
import invariant from 'tiny-invariant';

const FeatureCollectionContext = createContext<FeatureCollection | null>(null);

export function ReadableFeatureCollectionProvider({
  featureCollection,
  children
}: {
  featureCollection: FeatureCollection;
  children: ReactNode;
}) {
  return (
    <FeatureCollectionContext.Provider value={featureCollection}>
      {children}
    </FeatureCollectionContext.Provider>
  );
}

export function useFeatureCollection(): FeatureCollection {
  const featureCollection = useContext(FeatureCollectionContext);
  invariant(featureCollection, 'FeatureCollectionProvider is missing');
  return featureCollection;
}

// Memoized: the layers hand these features to the map, which compares them
// coordinate by coordinate on every change of identity.
export function useFeatures(source: string): Feature[] {
  const { features } = useFeatureCollection();
  return useMemo(
    () => features.filter((feature) => feature.properties?.source == source),
    [features, source]
  );
}

export function useFeature(id: string): Feature | undefined {
  const { features } = useFeatureCollection();
  return features.find((feature) => feature.properties?.id == id);
}
