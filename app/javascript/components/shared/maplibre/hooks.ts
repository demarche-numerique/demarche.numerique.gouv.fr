import type { Feature, Geometry } from 'geojson';
import type {
  LngLat,
  LngLatBoundsLike,
  LngLatLike,
  MapEventType,
  MapLayerEventType,
  StyleSpecification
} from 'maplibre-gl';
import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type RefObject
} from 'react';

import { useMapLibre } from './MapLibre';
import {
  getLayerName,
  getMapStyle,
  isParcelleLayer,
  type LayersMap
} from './styles';

export function useFitBounds() {
  const map = useMapLibre();
  return useCallback(
    (bbox: LngLatBoundsLike) => {
      map.fitBounds(bbox, { padding: 100 });
    },
    [map]
  );
}

export function useFitBoundsNoFly() {
  const map = useMapLibre();
  return useCallback(
    (bbox: LngLatBoundsLike) => {
      map.fitBounds(bbox, { padding: 100, linear: true, duration: 0 });
    },
    [map]
  );
}

export function useFlyTo() {
  const map = useMapLibre();
  return useCallback(
    (zoom: number, center: LngLatLike) => {
      map.flyTo({ zoom, center });
    },
    [map]
  );
}

export function useEvent<T>(
  eventName: string,
  callback: (event: CustomEvent<T>) => void
) {
  return useEffect(() => {
    addEventListener(eventName, callback as EventListener);
    return () => removeEventListener(eventName, callback as EventListener);
  }, [eventName, callback]);
}

export type EventHandler = (event: {
  features: Feature<Geometry>[];
  lngLat: LngLat;
}) => void;

export function useMapEvent(
  eventName: string,
  callback: EventHandler,
  target?: string
) {
  const map = useMapLibre();
  return useEffect(() => {
    if (target) {
      // event typing is hard
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      map.on(eventName as keyof MapLayerEventType, target, callback as any);
    } else {
      // draw.* events come from mapbox-gl-draw and are unknown to MapEventType
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      map.on(eventName as keyof MapEventType, callback as any);
    }
    return () => {
      if (target) {
        // event typing is hard
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        map.off(eventName as keyof MapLayerEventType, target, callback as any);
      } else {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        map.off(eventName as keyof MapEventType, callback as any);
      }
    };
  }, [map, eventName, target, callback]);
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

export function useStyle(
  optionalLayers: string[],
  onStyleChange: (style: StyleSpecification) => void
) {
  const [styleId, setStyle] = useState<'ortho' | 'vector' | 'ign'>('ortho');
  const [layers, setLayers] = useState(() => optionalLayersMap(optionalLayers));
  const setLayerEnabled = (layer: string, enabled: boolean) =>
    setLayers((optionalLayers) => {
      optionalLayers[layer].enabled = enabled;
      return { ...optionalLayers };
    });
  const setLayerOpacity = (layer: string, opacity: number) =>
    setLayers((optionalLayers) => {
      optionalLayers[layer].opacity = opacity;
      return { ...optionalLayers };
    });
  const enabledLayers = useMemo(
    () => Object.entries(layers).filter(([, { enabled }]) => enabled),
    [layers]
  );
  const style = useMemo(
    () =>
      getMapStyle(
        styleId,
        enabledLayers.map(([layer]) => layer),
        Object.fromEntries(
          enabledLayers.map(([layer, { opacity }]) => [layer, opacity])
        )
      ),
    [styleId, enabledLayers]
  );

  useEffect(() => onStyleChange(style), [onStyleChange, style]);

  return { style, layers, setStyle, setLayerEnabled, setLayerOpacity };
}

function isElementVisible(
  element: HTMLElement,
  callback: (visible: boolean) => void
) {
  if (element.offsetWidth > 0 && element.offsetHeight > 0) {
    callback(true);
  } else {
    callback(false);
    const observer = new IntersectionObserver(
      (entries) => callback(entries[0].isIntersecting == true),
      { threshold: [0] }
    );
    observer.observe(element);
    return () => observer.unobserve(element);
  }
}

export function useElementVisible(element: RefObject<HTMLElement | null>) {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (element.current) {
      return isElementVisible(element.current, setVisible);
    }
  }, [element]);
  return visible;
}
