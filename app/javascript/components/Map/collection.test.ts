import { suite, test, expect } from 'vitest';
import type { Feature } from 'geojson';

import {
  editorReducer,
  initEditorState,
  mergeSnapshot,
  normalizeFeature,
  type EditableFeature
} from './collection';

const drawn = normalizeFeature({
  type: 'Feature',
  geometry: { type: 'Point', coordinates: [2.4, 46.5] },
  properties: { id: 'drawn', source: 'selection_utilisateur' }
});
const parcelle = normalizeFeature({
  type: 'Feature',
  geometry: { type: 'Point', coordinates: [2.4, 46.5] },
  properties: { id: 'parcelle', source: 'cadastre', cid: '42' }
});

suite('collection', () => {
  test('a feature gets its id from its properties', () => {
    expect(drawn.id).toBe('drawn');
    expect(drawn.properties?.id).toBe('drawn');
  });

  test('the server brings its properties and the geometry of parcelles', () => {
    const server: Feature[] = [
      {
        ...drawn,
        geometry: { type: 'Point', coordinates: [0, 0] },
        properties: { ...drawn.properties, description: 'old', area: 12 }
      },
      {
        ...parcelle,
        geometry: { type: 'Point', coordinates: [1, 1] },
        properties: { ...parcelle.properties, numero: '42' }
      }
    ];
    const local = [
      { ...drawn, properties: { ...drawn.properties, description: 'new' } },
      parcelle
    ];

    const [mergedDrawn, mergedParcelle] = mergeSnapshot(local, server);

    expect(mergedDrawn.geometry).toEqual(drawn.geometry);
    expect(mergedDrawn.properties).toMatchObject({
      description: 'new',
      area: 12
    });
    expect(mergedParcelle.geometry).toEqual({
      type: 'Point',
      coordinates: [1, 1]
    });
    expect(mergedParcelle.properties?.numero).toBe('42');
  });

  test('a rejected feature goes back to the server version, or away', () => {
    const moved = {
      ...drawn,
      geometry: { type: 'Point' as const, coordinates: [300, 100] }
    };
    const added = normalizeFeature({ ...drawn, id: 'added', properties: {} });

    expect(mergeSnapshot([moved, added], [drawn], ['drawn', 'added'])).toEqual([
      drawn
    ]);
  });

  test('features the server does not know are kept, unknown ones ignored', () => {
    const local = [drawn];
    expect(mergeSnapshot(local, [parcelle])).toBe(local);
    expect(mergeSnapshot(local, [drawn])).toBe(local);
  });

  suite('history', () => {
    const add = (feature: EditableFeature) => (features: EditableFeature[]) => [
      ...features,
      feature
    ];
    const describe = (description: string) => (features: EditableFeature[]) =>
      features.map((feature) => ({
        ...feature,
        properties: { ...feature.properties, description }
      }));

    test('undo and redo restore the collection, and are saved', () => {
      let state = initEditorState([drawn]);
      state = editorReducer(state, { type: 'change', update: add(parcelle) });
      expect(state.features).toEqual([drawn, parcelle]);

      state = editorReducer(state, { type: 'undo' });
      expect(state.features).toEqual([drawn]);
      expect(state.revision).toBe(2);

      state = editorReducer(state, { type: 'redo' });
      expect(state.features).toEqual([drawn, parcelle]);
      expect(state.revision).toBe(3);
      expect(editorReducer(state, { type: 'redo' })).toBe(state);
    });

    test('a new change forgets what was undone', () => {
      let state = initEditorState([]);
      state = editorReducer(state, { type: 'change', update: add(drawn) });
      state = editorReducer(state, { type: 'undo' });
      state = editorReducer(state, { type: 'change', update: add(parcelle) });
      expect(state.future).toEqual([]);
    });

    test('the keystrokes of a description are one step', () => {
      let state = initEditorState([drawn]);
      for (const description of ['M', 'Mo', 'Mon']) {
        state = editorReducer(state, {
          type: 'change',
          update: describe(description),
          coalesce: 'properties:drawn'
        });
      }
      state = editorReducer(state, { type: 'undo' });
      expect(state.features).toEqual([drawn]);
    });

    test('the server snapshot is not a step, nor a change to save', () => {
      let state = initEditorState([parcelle]);
      state = editorReducer(state, {
        type: 'merge',
        snapshot: [
          { ...parcelle, properties: { ...parcelle.properties, numero: '1' } }
        ]
      });
      expect(state.past).toEqual([]);
      expect(state.revision).toBe(0);
    });
  });
});
