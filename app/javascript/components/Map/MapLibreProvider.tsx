import { createContext, useContext, useId, type ReactNode } from 'react';
import { MapProvider, useMap, type MapRef } from '@vis.gl/react-maplibre';
import { addProtocol, setWorkerUrl } from 'maplibre-gl';
import { Protocol } from 'pmtiles';
import invariant from 'tiny-invariant';
import 'maplibre-gl/dist/maplibre-gl.css';
// maplibre-gl 6 resolves its worker from import.meta.url, which does not
// survive bundling: hand Vite's self-contained worker URL over instead.
// https://maplibre.org/maplibre-gl-js/docs/#installation
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';

setWorkerUrl(workerUrl);
addProtocol('pmtiles', new Protocol().tile);

// Every provider holds a single map. Its id also ends up on the container of
// the map, so it has to be unique on a page showing several maps.
const MapIdContext = createContext<string | undefined>(undefined);

export function MapLibreProvider({ children }: { children: ReactNode }) {
  const mapId = useId();
  return (
    <MapIdContext.Provider value={mapId}>
      <MapProvider>{children}</MapProvider>
    </MapIdContext.Provider>
  );
}

export function useMapId(): string {
  const mapId = useContext(MapIdContext);
  invariant(mapId, 'MapLibreProvider is missing');
  return mapId;
}

// The map is missing until the canvas is mounted, and stays so when the browser
// cannot render it: components living outside the canvas have to cope with it.
export function useMapLibre(): MapRef | undefined {
  const maps = useMap();
  const mapId = useMapId();
  return maps.current ?? maps[mapId];
}
