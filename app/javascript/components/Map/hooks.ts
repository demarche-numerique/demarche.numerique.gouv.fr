import { useEffect, useMemo, useState, type RefObject } from 'react';

import {
  getLayerName,
  getMapStyle,
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
  // The map applies a style as soon as its identity changes: build a new one
  // only when it really changed, or every render would recreate the sources
  // and refetch the tiles.
  const style = useMemo(() => {
    const enabledLayers = Object.entries(layers).filter(
      ([, { enabled }]) => enabled
    );
    return getMapStyle(
      styleId,
      enabledLayers.map(([layer]) => layer),
      Object.fromEntries(
        enabledLayers.map(([layer, { opacity }]) => [layer, opacity])
      )
    );
  }, [styleId, layers]);

  return { style, layers, setStyle, setLayerEnabled, setLayerOpacity };
}

function optionalLayersMap(optionalLayers: string[]): LayersMap {
  return Object.fromEntries(
    optionalLayers.map((layer) => [
      layer,
      {
        configurable: layer != 'cadastres',
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
