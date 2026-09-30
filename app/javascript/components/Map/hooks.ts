import {
  createContext,
  use,
  useEffect,
  useMemo,
  useState,
  type RefObject
} from 'react';

import {
  getLayerName,
  getMapStyle,
  isParcelleLayer,
  type LayersMap,
  type MapStyle
} from '../shared/maplibre/styles';

export function useMapStyle(optionalLayers: string[]) {
  const [styleId, setStyle] = useState<MapStyle>('ortho');
  const [layers, setLayers] = useState(() => optionalLayersMap(optionalLayers));
  const setLayerEnabled = (layer: string, enabled: boolean) =>
    setLayers((layers) => ({
      ...layers,
      [layer]: { ...layers[layer], enabled }
    }));
  const setLayerOpacity = (layer: string, opacity: number) =>
    setLayers((layers) => ({
      ...layers,
      [layer]: { ...layers[layer], opacity }
    }));
  // The optional layers are not part of the style: they are React layers, so
  // that toggling one or moving its opacity never applies a new style, which
  // would drop and re-add every React layer on the map. The style only
  // changes with the basemap.
  const style = useMemo(() => getMapStyle(styleId, [], {}), [styleId]);

  return { style, layers, setStyle, setLayerEnabled, setLayerOpacity };
}

// The basemap currently shown by the canvas. Layers the map style does not
// know about, like the drawing layers, must be removed before the canvas
// applies another basemap and added back once it is in.
export const MapStyleIdContext = createContext<string | undefined>(undefined);

export function useMapStyleId() {
  return use(MapStyleIdContext);
}

function optionalLayersMap(optionalLayers: string[]): LayersMap {
  return Object.fromEntries(
    optionalLayers.map((layer) => [
      layer,
      {
        // The parcelle layer shows the parcelles of the dossier: always on.
        configurable: !isParcelleLayer(layer),
        enabled: true,
        opacity: 70,
        name: getLayerName(layer)
      }
    ])
  );
}

// A map created in a hidden container (a collapsed section, an inactive tab)
// gets a size of zero: wait for the container to get one.
export function useElementVisible(element: RefObject<HTMLElement | null>) {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (!element.current) {
      return;
    }
    const observer = new ResizeObserver(([entry]) => {
      if (entry.contentRect.width > 0 && entry.contentRect.height > 0) {
        setVisible(true);
        observer.disconnect();
      }
    });
    observer.observe(element.current);
    return () => observer.disconnect();
  }, [element]);
  return visible;
}
