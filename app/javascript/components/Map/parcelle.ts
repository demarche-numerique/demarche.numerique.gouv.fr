import type { GeoJsonProperties } from 'geojson';
import type { MapGeoJSONFeature } from 'maplibre-gl';
import { useLingui } from '@lingui/react/macro';

import { PARCELLE_LAYERS } from '../shared/maplibre/styles';

type ParcelleSource =
  (typeof PARCELLE_LAYERS)[keyof typeof PARCELLE_LAYERS]['source'];

// What the map says of a parcelle, wherever it comes from.
export type ParcelleInfo = {
  source: ParcelleSource;
  numero: string;
  prefixe?: string;
  section?: string;
  commune?: string;
  // In square meters.
  surface?: number;
};

export function isParcelleSource(source: unknown): source is ParcelleSource {
  return Object.values(PARCELLE_LAYERS).some((layer) => layer.source == source);
}

// A parcelle of the dossier, as GeoArea#to_feature describes it.
export function parcelleInfo(
  properties: GeoJsonProperties
): ParcelleInfo | null {
  const source = properties?.source;
  if (!isParcelleSource(source) || properties?.cid == null) {
    return null;
  }
  if (source == 'rpg') {
    return { source, numero: String(properties.cid), surface: properties.area };
  }
  return {
    source,
    numero: properties.numero ?? String(properties.cid),
    prefixe: properties.prefixe,
    section: properties.section,
    commune: properties.commune,
    surface: properties.surface
  };
}

// The id of a parcelle of the tiles, as the dossier keeps it (`cid`).
export function tileParcelleId(parcelle: MapGeoJSONFeature): string | null {
  const layer = Object.values(PARCELLE_LAYERS).find(
    ({ source }) => source == parcelle.source
  );
  const id = layer ? parcelle.properties[layer.idProperty] : null;
  return id == null ? null : String(id);
}

// "Parcelle n° 42 – Feuille 000 AB – 1 234 m² – commune 75056", as the list
// of the champ labels it. A number never leaves its unit on the line above.
export function useParcelleLabel() {
  const { t, i18n } = useLingui();
  const squareMeters = new Intl.NumberFormat(i18n.locale, {
    maximumFractionDigits: 0
  });
  const hectares = new Intl.NumberFormat(i18n.locale, {
    maximumFractionDigits: 2
  });

  return ({
    source,
    numero,
    prefixe,
    section,
    commune,
    surface
  }: ParcelleInfo) => {
    const parts = [t`Parcelle n°\u00a0${numero}`];
    if (section) {
      const feuille = [prefixe, section].filter(Boolean).join('\u00a0');
      parts.push(t`Feuille ${feuille}`);
    }
    if (surface != null && source == 'rpg') {
      const area = hectares.format(surface / 10_000);
      parts.push(t`${area}\u00a0hectares`);
    } else if (surface != null) {
      const area = squareMeters.format(surface);
      parts.push(t`${area}\u00a0m²`);
    }
    if (commune) {
      parts.push(t`commune ${commune}`);
    }
    return parts.join(' – ');
  };
}
