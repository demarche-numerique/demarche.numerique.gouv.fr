import type { ReactNode } from 'react';
import { MapProvider, useMap, type MapRef } from '@vis.gl/react-maplibre';
import { addProtocol, setWorkerUrl } from 'maplibre-gl';
import { Protocol } from 'pmtiles';
import 'maplibre-gl/dist/maplibre-gl.css';
// maplibre-gl 6 resolves its worker from import.meta.url, which does not
// survive bundling: hand Vite's self-contained worker URL over instead.
// https://maplibre.org/maplibre-gl-js/docs/#installation
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';

setWorkerUrl(workerUrl);
addProtocol('pmtiles', new Protocol().tile);

// Every provider holds a single map, so a constant id is enough to find it.
export const MAP_ID = 'carte';

export function MapLibreProvider({ children }: { children: ReactNode }) {
  return <MapProvider>{children}</MapProvider>;
}

// The map is missing until the canvas is mounted, and stays so when the browser
// cannot render it: components living outside the canvas have to cope with it.
export function useMapLibre(): MapRef | undefined {
  const maps = useMap();
  return maps.current ?? maps[MAP_ID];
}
