import type { Feature, FeatureCollection } from 'geojson';

export type EditableFeature = Feature & { id: string };

// The server names its features in their properties (`properties.id`); the
// editor also needs the GeoJSON id, which Terra Draw and the payload use.
export function normalizeFeature(feature: Feature): EditableFeature {
  const id = String(feature.id ?? feature.properties?.id);
  return { ...feature, id, properties: { ...feature.properties, id } };
}

// The collection the server rendered after a save. The editor owns its
// features: the server only brings what it computes (area, length, the
// labels of a parcelle), and the real geometry of a parcelle. A feature it
// does not know yet, being saved, is left alone, and so is one it knows but
// the usager has since removed. A feature the server rejected (an invalid
// geometry) goes back to what the server has, or goes away.
export function mergeSnapshot(
  features: EditableFeature[],
  snapshot: Feature[],
  rejected: string[] = []
): EditableFeature[] {
  const remote = new Map(
    snapshot.map((feature) => {
      const normalized = normalizeFeature(feature);
      return [normalized.id, normalized];
    })
  );
  let changed = false;
  const merged = features.flatMap((feature) => {
    const server = remote.get(feature.id);
    if (rejected.includes(feature.id)) {
      changed = true;
      return server ? [server] : [];
    }
    if (!server) {
      return feature;
    }
    const drawn = feature.properties?.source == 'selection_utilisateur';
    const next: EditableFeature = {
      ...feature,
      geometry: drawn ? feature.geometry : server.geometry,
      properties: {
        ...server.properties,
        description: feature.properties?.description
      }
    };
    if (JSON.stringify(next) == JSON.stringify(feature)) {
      return feature;
    }
    changed = true;
    return next;
  });
  return changed ? merged : features;
}

// The value of the champ: the server syncs its geo areas with it.
export function serializeFeatures(features: EditableFeature[]) {
  const featureCollection: FeatureCollection = {
    type: 'FeatureCollection',
    features
  };
  return JSON.stringify(featureCollection);
}

// How many changes the editor can undo.
const HISTORY_SIZE = 100;

export type EditorState = {
  features: EditableFeature[];
  past: EditableFeature[][];
  future: EditableFeature[][];
  // Bumped by every change of the usager, undo and redo included: each is
  // saved. Merging the server snapshot is not a change.
  revision: number;
  // Consecutive changes with the same key make a single step of history
  // (the keystrokes of a description).
  coalesce?: string;
};

export type EditorAction =
  | {
      type: 'change';
      update: (features: EditableFeature[]) => EditableFeature[];
      coalesce?: string;
    }
  | { type: 'undo' }
  | { type: 'redo' }
  | { type: 'merge'; snapshot: Feature[]; rejected?: string[] };

export function initEditorState(features: Feature[]): EditorState {
  return {
    features: features.map(normalizeFeature),
    past: [],
    future: [],
    revision: 0
  };
}

export function editorReducer(
  state: EditorState,
  action: EditorAction
): EditorState {
  switch (action.type) {
    case 'change': {
      const features = action.update(state.features);
      if (features === state.features) {
        return state;
      }
      const coalesced =
        action.coalesce != null && action.coalesce == state.coalesce;
      return {
        features,
        past: coalesced
          ? state.past
          : [...state.past, state.features].slice(-HISTORY_SIZE),
        future: [],
        revision: state.revision + 1,
        coalesce: action.coalesce
      };
    }
    case 'undo': {
      const previous = state.past.at(-1);
      if (!previous) {
        return state;
      }
      return {
        features: previous,
        past: state.past.slice(0, -1),
        future: [state.features, ...state.future],
        revision: state.revision + 1
      };
    }
    case 'redo': {
      const [next, ...future] = state.future;
      if (!next) {
        return state;
      }
      return {
        features: next,
        past: [...state.past, state.features],
        future,
        revision: state.revision + 1
      };
    }
    case 'merge': {
      const features = mergeSnapshot(
        state.features,
        action.snapshot,
        action.rejected
      );
      return features === state.features ? state : { ...state, features };
    }
  }
}
