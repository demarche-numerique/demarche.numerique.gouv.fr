import { suite, test, expect } from 'vitest';

import {
  ANCHORS,
  buildOptionalLayers,
  getMapStyle,
  type MapStyle
} from './index';

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
            expect(sources, `${id} / [${selection}] / ${layer.id}`).toContain(
              layer.source
            );
          }
        }
      }
    }
  });

  test('credits every source, each credit spelled the same everywhere', () => {
    const style = getMapStyle('vector', ['cadastres', 'unesco'], {
      cadastres: 70,
      unesco: 70
    });
    const credits = new Set<string>();

    for (const [id, source] of Object.entries(style.sources)) {
      expect(source, id).toHaveProperty('attribution');
      for (const credit of (
        source as { attribution: string }
      ).attribution.split(/(?<=<\/a>) /)) {
        credits.add(credit);
      }
    }

    expect(
      [...credits].map((credit) => credit.replace(/<[^>]+>/g, ''))
    ).toEqual([
      '© DINUM (data.gouv.fr)',
      '© Contributeurs OpenStreetMap',
      '© OpenMapTiles',
      '© IGN',
      '© PatriNat (OFB-MNHN-CNRS-IRD)'
    ]);
  });

  test('closes every basemap with the anchors, in order', () => {
    for (const id of STYLES) {
      const ids = getMapStyle(id, ['cadastres'], OPACITY).layers.map(
        (layer) => layer.id
      );
      expect(ids.slice(-2), id).toEqual([
        ANCHORS.optionalLayers,
        ANCHORS.selections
      ]);
    }
  });

  test('highlights the parcelles of the dossier by their id property', () => {
    const highlight = (layers: string[]) =>
      buildOptionalLayers(layers, OPACITY, ['a', 'b']).find(
        (layer) => layer.id == 'parcelle-highlighted'
      );

    expect(highlight(['cadastres'])).toHaveProperty('filter', [
      'in',
      ['get', 'id'],
      ['literal', ['a', 'b']]
    ]);
    expect(highlight(['rpg'])).toHaveProperty('filter', [
      'in',
      ['get', 'ID_PARCEL'],
      ['literal', ['a', 'b']]
    ]);
  });

  test('highlights a parcelle under its numero', () => {
    const ids = buildOptionalLayers(['cadastres'], OPACITY).map(
      (layer) => layer.id
    );

    expect(ids.indexOf('parcelle-highlighted')).toBeGreaterThan(
      ids.indexOf('parcelles-fill')
    );
    expect(ids.indexOf('parcelle-highlighted')).toBeLessThan(
      ids.indexOf('parcelles-labels')
    );
  });

  test('refuses both parcelle layers at once', () => {
    expect(() => buildOptionalLayers(['cadastres', 'rpg'], OPACITY)).toThrow(
      /one parcelle layer/
    );
  });
});
