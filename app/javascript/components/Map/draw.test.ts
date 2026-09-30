import { suite, test, expect } from 'vitest';
import type { Feature, Polygon } from 'geojson';

import {
  isDrawable,
  planSync,
  roundGeometry,
  serializeGeometry,
  type DrawableGeometry
} from './draw';

const square: Polygon = {
  type: 'Polygon',
  coordinates: [
    [
      [2.4284398555756, 46.5384768377257],
      [2.4284291267395, 46.5384214875816],
      [2.4282521009445, 46.5384141075581],
      [2.4284398555756, 46.5384768377257]
    ]
  ]
};

function feature(id: string, geometry: DrawableGeometry) {
  return {
    type: 'Feature',
    id,
    geometry,
    properties: { source: 'selection_utilisateur' }
  } satisfies Feature & { id: string };
}

suite('draw', () => {
  test('only the shapes of the usager are drawn', () => {
    expect(isDrawable(feature('a', square))).toBe(true);
    expect(
      isDrawable({
        ...feature('a', square),
        properties: { source: 'cadastre' }
      })
    ).toBe(false);
    expect(
      isDrawable({
        ...feature('a', square),
        geometry: { type: 'MultiPolygon', coordinates: [square.coordinates] }
      } as Feature)
    ).toBe(false);
  });

  test('coordinates are rounded to about ten centimetres', () => {
    expect(roundGeometry(square).coordinates[0][0]).toEqual([
      2.42844, 46.538477
    ]);
  });

  test('plans what Terra Draw must add, update and remove', () => {
    const moved: Polygon = {
      ...square,
      coordinates: [square.coordinates[0].map(([x, y]) => [x + 0.001, y])]
    };
    const drawn = new Map([
      ['kept', serializeGeometry(roundGeometry(square))],
      ['moved', serializeGeometry(roundGeometry(square))],
      ['removed', serializeGeometry(roundGeometry(square))]
    ]);

    const { add, update, remove } = planSync(drawn, [
      feature('kept', square),
      feature('moved', moved),
      feature('added', square)
    ]);

    expect(add).toEqual([
      {
        id: 'added',
        type: 'Feature',
        geometry: roundGeometry(square),
        properties: { mode: 'polygon' }
      }
    ]);
    expect(update).toEqual([['moved', roundGeometry(moved)]]);
    expect(remove).toEqual(['removed']);
  });
});
