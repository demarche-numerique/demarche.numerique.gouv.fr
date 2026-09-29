import { suite, test, expect } from 'vitest';

import { getBounds } from './geometry';

suite('getBounds', () => {
  test('a point', () => {
    const bounds = getBounds({ type: 'Point', coordinates: [2.35, 48.85] });

    expect(bounds.toArray()).toEqual([
      [2.35, 48.85],
      [2.35, 48.85]
    ]);
  });

  test('every polygon of a multi polygon', () => {
    const bounds = getBounds({
      type: 'MultiPolygon',
      coordinates: [
        [
          [
            [1, 1],
            [2, 1],
            [2, 2],
            [1, 1]
          ]
        ],
        [
          [
            [5, 5],
            [6, 5],
            [6, 7],
            [5, 5]
          ]
        ]
      ]
    });

    expect(bounds.toArray()).toEqual([
      [1, 1],
      [6, 7]
    ]);
  });

  test('every geometry of a collection', () => {
    const bounds = getBounds({
      type: 'GeometryCollection',
      geometries: [
        { type: 'Point', coordinates: [3, 4, 120] },
        {
          type: 'LineString',
          coordinates: [
            [-1, 2],
            [0, 8]
          ]
        }
      ]
    });

    expect(bounds.toArray()).toEqual([
      [-1, 2],
      [3, 8]
    ]);
  });
});
