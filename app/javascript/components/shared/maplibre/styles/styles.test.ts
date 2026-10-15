import { suite, test, expect } from 'vite-plus/test';

import { getMapStyle, type MapStyle } from './index';

const STYLES: MapStyle[] = ['ortho', 'vector', 'ign'];
// `cadastres` and `rpg` share layer ids, so they are never enabled together.
const SELECTIONS = [[], ['cadastres'], ['rpg']];
const OPACITY = { cadastres: 70, rpg: 70 };

suite('getMapStyle', () => {
  test('declares a parcelle source only when its layer is enabled', () => {
    expect(getMapStyle('ortho', [], OPACITY).sources).not.toHaveProperty('rpg');
    expect(getMapStyle('ortho', [], OPACITY).sources).not.toHaveProperty(
      'cadastre'
    );
    expect(getMapStyle('ortho', ['rpg'], OPACITY).sources).toHaveProperty(
      'rpg'
    );
    expect(getMapStyle('ortho', ['cadastres'], OPACITY).sources).toHaveProperty(
      'cadastre'
    );
  });

  test('never references a source it does not declare', () => {
    for (const id of STYLES) {
      for (const selection of SELECTIONS) {
        const style = getMapStyle(id, selection, OPACITY);
        const sources = Object.keys(style.sources);

        for (const layer of style.layers) {
          if ('source' in layer) {
            expect(
              sources,
              `${id} / [${selection.join(', ')}] / ${layer.id}`
            ).toContain(layer.source);
          }
        }
      }
    }
  });
});
