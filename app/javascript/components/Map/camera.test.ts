import { vi, suite, test, expect } from 'vitest';

import { fitGeometry } from './camera';

function fakeMap() {
  return {
    fitBounds: vi.fn(),
    getContainer: () => ({ clientWidth: 320, clientHeight: 500 }) as HTMLElement
  };
}

suite('fitGeometry', () => {
  test('leaves half of the map around a shape', () => {
    const map = fakeMap();

    fitGeometry(map, {
      type: 'LineString',
      coordinates: [
        [2.35, 48.85],
        [2.36, 48.87]
      ]
    });

    expect(map.fitBounds.mock.calls[0][1]).toEqual({
      padding: { top: 125, bottom: 125, left: 80, right: 80 },
      maxZoom: 18
    });
  });

  test('stays further away from a point', () => {
    const map = fakeMap();

    fitGeometry(map, { type: 'Point', coordinates: [2.35, 48.85] });

    expect(map.fitBounds.mock.calls[0][1]).toMatchObject({ maxZoom: 17 });
  });
});
