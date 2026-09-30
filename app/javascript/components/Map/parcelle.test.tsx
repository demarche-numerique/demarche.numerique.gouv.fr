import { suite, test, expect } from 'vite-plus/test';
import { flushSync } from 'react-dom';
import type { MapGeoJSONFeature } from 'maplibre-gl';

import {
  parcelleInfo,
  tileParcelleId,
  useParcelleLabel,
  type ParcelleInfo
} from './parcelle';
import { createAppRoot } from '../../test/react';

function tileParcelle(
  source: string,
  properties: Record<string, unknown>
): MapGeoJSONFeature {
  return { source, properties } as unknown as MapGeoJSONFeature;
}

function Label({ info }: { info: ParcelleInfo }) {
  return useParcelleLabel()(info);
}

function label(info: ParcelleInfo) {
  const container = document.createElement('div');
  const root = createAppRoot(container);
  flushSync(() => root.render(<Label info={info} />));
  const result = container.textContent;
  root.unmount();
  // Intl separates the thousands with a narrow no-break space.
  return result.replace(/\u202f/g, ' ');
}

const cadastre = {
  source: 'cadastre',
  numero: '42',
  prefixe: '000',
  section: 'AB',
  commune: '75056'
} as const;

suite('parcelle', () => {
  test('describes a parcelle of the dossier', () => {
    expect(
      parcelleInfo({
        ...cadastre,
        id: 'uuid',
        cid: '75056000AB0042',
        surface: 1300
      })
    ).toEqual({
      source: 'cadastre',
      numero: '42',
      prefixe: '000',
      section: 'AB',
      commune: '75056',
      surface: 1300
    });
    expect(parcelleInfo({ source: 'rpg', cid: '12345', area: 25000 })).toEqual({
      source: 'rpg',
      numero: '12345',
      surface: 25000
    });
    expect(parcelleInfo({ source: 'selection_utilisateur', id: 'x' })).toBe(
      null
    );
  });

  test('finds the id of a parcelle of the tiles', () => {
    expect(tileParcelleId(tileParcelle('rpg', { ID_PARCEL: 7 }))).toBe('7');
    expect(
      tileParcelleId(tileParcelle('cadastre', { id: '75056000AB0042' }))
    ).toBe('75056000AB0042');
  });

  test('labels a parcelle as the list of the champ does', () => {
    expect(
      label({
        source: 'cadastre',
        numero: '42',
        prefixe: '000',
        section: 'AB',
        commune: '75056',
        surface: 1234
      })
    ).toBe(
      'Parcelle n°\u00a042 – Feuille 000\u00a0AB – 1 234\u00a0m² – commune 75056'
    );
    expect(label({ source: 'rpg', numero: '7', surface: 25000 })).toBe(
      'Parcelle n°\u00a07 – 2,5\u00a0hectares'
    );
    expect(label({ source: 'cadastre', numero: '42' })).toBe(
      'Parcelle n°\u00a042'
    );
  });
});
