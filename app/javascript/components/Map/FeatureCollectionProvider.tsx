import {
  createContext,
  useContext,
  useLayoutEffect,
  useMemo,
  useState,
  useSyncExternalStore,
  type ReactNode
} from 'react';
import type { Feature, FeatureCollection } from 'geojson';
import invariant from 'tiny-invariant';

const FeatureCollectionContext = createContext<FeatureCollection | null>(null);
// The features by id. Every line of the list looks its feature up, and a champ
// may hold hundreds of parcelles: a line subscribes to its own feature, and
// renders again only when that feature changes, not whenever the collection
// does.
class FeatureIndex {
  #features: Map<string, Feature>;
  #listeners = new Set<() => void>();

  constructor(features: Feature[]) {
    this.#features = FeatureIndex.#build(features);
  }

  get(id: string) {
    return this.#features.get(id);
  }

  set(features: Feature[]) {
    this.#features = FeatureIndex.#build(features);
    this.#listeners.forEach((listener) => listener());
  }

  subscribe = (listener: () => void) => {
    this.#listeners.add(listener);
    return () => this.#listeners.delete(listener);
  };

  static #build(features: Feature[]) {
    return new Map(
      features.map((feature) => [String(feature.properties?.id), feature])
    );
  }
}

const FeatureIndexContext = createContext<FeatureIndex>(new FeatureIndex([]));

export function ReadableFeatureCollectionProvider({
  featureCollection,
  children
}: {
  featureCollection: FeatureCollection;
  children: ReactNode;
}) {
  return (
    <FeatureCollectionContextProvider value={featureCollection}>
      {children}
    </FeatureCollectionContextProvider>
  );
}

function FeatureCollectionContextProvider({
  value,
  children
}: {
  value: FeatureCollection;
  children: ReactNode;
}) {
  const [index] = useState(() => new FeatureIndex(value.features));
  // Before paint: the lines show the new features in the same commit as the
  // rest of the map.
  useLayoutEffect(() => index.set(value.features), [index, value.features]);
  return (
    <FeatureCollectionContext.Provider value={value}>
      <FeatureIndexContext.Provider value={index}>
        {children}
      </FeatureIndexContext.Provider>
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
  const index = useContext(FeatureIndexContext);
  return useSyncExternalStore(index.subscribe, () => index.get(id));
}
