import { createContext, useContext, type ReactNode } from 'react';
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

export function useFeatures(source: string): Feature[] {
  const { features } = useFeatureCollection();
  return features.filter((feature) => feature.properties?.source == source);
}

export function useFeature(id: string): Feature | undefined {
  const { features } = useFeatureCollection();
  return features.find((feature) => feature.properties?.id == id);
}
