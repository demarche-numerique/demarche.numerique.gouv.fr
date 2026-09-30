import {
  createContext,
  useContext,
  useLayoutEffect,
  useMemo,
  useReducer,
  useState,
  useSyncExternalStore,
  type ReactNode
} from 'react';
import type {
  Feature,
  FeatureCollection,
  GeoJsonProperties,
  Geometry
} from 'geojson';
import invariant from 'tiny-invariant';

import {
  editorReducer,
  initEditorState,
  normalizeFeature,
  type EditableFeature
} from './collection';

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

export type FeatureActions = {
  create: (features: Feature[]) => void;
  update: (
    id: string,
    changes: { geometry?: Geometry; properties?: GeoJsonProperties }
  ) => void;
  remove: (ids: string[]) => void;
};

const FeatureActionsContext = createContext<FeatureActions | null>(null);
// Bumped by every change the usager makes, and only by those: the server
// snapshot merged after a save is not a change to save again.
const RevisionContext = createContext(0);

export type History = {
  canUndo: boolean;
  canRedo: boolean;
  undo: () => void;
  redo: () => void;
};

const HistoryContext = createContext<History | null>(null);

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
  // Before paint, and before React hands a typed description back to its
  // input: the lines read the new features in the same commit.
  useLayoutEffect(() => index.set(value.features), [index, value.features]);
  return (
    <FeatureCollectionContext.Provider value={value}>
      <FeatureIndexContext.Provider value={index}>
        {children}
      </FeatureIndexContext.Provider>
    </FeatureCollectionContext.Provider>
  );
}

// The editor owns the collection: it starts from the server's, and merges the
// server's again after each save (see `mergeSnapshot`).
export function WritableFeatureCollectionProvider({
  featureCollection,
  rejected,
  children
}: {
  featureCollection: FeatureCollection;
  // The features the server left out of the last save.
  rejected?: string[];
  children: ReactNode;
}) {
  const [state, dispatch] = useReducer(
    editorReducer,
    featureCollection.features,
    initEditorState
  );
  const { features, revision, past, future } = state;
  const [snapshot, setSnapshot] = useState(featureCollection);

  if (snapshot !== featureCollection) {
    setSnapshot(featureCollection);
    dispatch({ type: 'merge', snapshot: featureCollection.features, rejected });
  }

  const actions = useMemo<FeatureActions>(() => {
    const change = (
      update: (features: EditableFeature[]) => EditableFeature[],
      coalesce?: string
    ) => dispatch({ type: 'change', update, coalesce });
    return {
      create: (created) =>
        change((features) => [
          ...features,
          ...created.map((feature) =>
            normalizeFeature({
              ...feature,
              id: feature.id ?? crypto.randomUUID(),
              properties: {
                source: 'selection_utilisateur',
                ...feature.properties
              }
            })
          )
        ]),
      update: (id, { geometry, properties }) =>
        change(
          (features) =>
            features.map((feature) =>
              feature.id == id
                ? {
                    ...feature,
                    geometry: geometry ?? feature.geometry,
                    properties: { ...feature.properties, ...properties }
                  }
                : feature
            ),
          // Typing a description is one step of history, not one per key.
          geometry ? undefined : `properties:${id}`
        ),
      remove: (ids) =>
        change((features) => {
          const kept = features.filter((feature) => !ids.includes(feature.id));
          return kept.length == features.length ? features : kept;
        })
    };
  }, []);

  const history = useMemo<History>(
    () => ({
      canUndo: past.length > 0,
      canRedo: future.length > 0,
      undo: () => dispatch({ type: 'undo' }),
      redo: () => dispatch({ type: 'redo' })
    }),
    [past, future]
  );

  const value = useMemo(
    () => ({ ...featureCollection, features }),
    [featureCollection, features]
  );

  return (
    <FeatureCollectionContextProvider value={value}>
      <FeatureActionsContext.Provider value={actions}>
        <HistoryContext.Provider value={history}>
          <RevisionContext.Provider value={revision}>
            {children}
          </RevisionContext.Provider>
        </HistoryContext.Provider>
      </FeatureActionsContext.Provider>
    </FeatureCollectionContextProvider>
  );
}

// Only in an editor.
export function useFeatureActions(): FeatureActions | null {
  return useContext(FeatureActionsContext);
}

// Only in an editor.
export function useHistory(): History | null {
  return useContext(HistoryContext);
}

export function useRevision() {
  return useContext(RevisionContext);
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
