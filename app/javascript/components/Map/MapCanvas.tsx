import { useRef, useState } from 'react';
import {
  Map,
  NavigationControl,
  Popup,
  type MapLayerMouseEvent
} from '@vis.gl/react-maplibre';
import { LngLatBounds } from 'maplibre-gl';
import { Trans } from '@lingui/react/macro';
import invariant from 'tiny-invariant';

import { StyleSwitch } from '../shared/maplibre/StyleControl';
import { MAP_ID } from './MapLibreProvider';
import { useFeatureCollection } from './FeatureCollectionProvider';
import { PortalControl } from './PortalControl';
import { AttributionControl } from './AttributionControl';
import { OptionalLayers } from './OptionalLayers';
import { SelectionsLayer, SELECTIONS_LAYERS } from './SelectionsLayer';
import { ParcellesLayer, type ParcellesSource } from './ParcellesLayer';
import { useElementVisible, useMapStyle } from './hooks';
import { getBounds } from './geometry';
import { getMaxZoom } from './camera';
import './Popup.css';

// maplibre-gl 6 requires WebGL2: a WebGL1-only browser must get our banner,
// not maplibre's own error.
const webglSupported = isWebglSupported();

type Hovered = {
  id: string;
  description: string;
  longitude: number;
  latitude: number;
};

export function MapCanvas({ layers }: { layers: string[] }) {
  const bounds = useBounds();
  const containerRef = useRef<HTMLDivElement>(null);
  const visible = useElementVisible(containerRef);
  const { style, layers: optionalLayers, ...styleProps } = useMapStyle(layers);
  const [hovered, onMouseMove, onMouseLeave] = useHoveredFeature();
  const parcellesSource = getParcellesSource(optionalLayers);

  if (!webglSupported) {
    return <UnsupportedBrowser />;
  }

  return (
    <div ref={containerRef} style={{ height: '500px' }}>
      {visible ? (
        <Map
          id={MAP_ID}
          mapStyle={style}
          initialViewState={{
            bounds,
            fitBoundsOptions: { padding: 100, maxZoom: getMaxZoom(bounds) }
          }}
          attributionControl={false}
          interactiveLayerIds={SELECTIONS_LAYERS}
          cursor={hovered ? 'pointer' : undefined}
          onMouseMove={onMouseMove}
          onMouseLeave={onMouseLeave}
        >
          <NavigationControl position="top-right" />
          <AttributionControl />
          <PortalControl position="bottom-left">
            <StyleSwitch
              styleId={style.id}
              layers={optionalLayers}
              {...styleProps}
            />
          </PortalControl>
          <OptionalLayers layers={optionalLayers} />
          <SelectionsLayer />
          {parcellesSource ? <ParcellesLayer source={parcellesSource} /> : null}
          {hovered ? (
            <Popup
              longitude={hovered.longitude}
              latitude={hovered.latitude}
              closeButton={false}
              closeOnClick={false}
              className="map-popup"
            >
              {hovered.description}
            </Popup>
          ) : null}
        </Map>
      ) : null}
    </div>
  );
}

function useBounds() {
  const { bbox } = useFeatureCollection();
  invariant(bbox, 'The feature collection has no bbox');
  const [west, south, east, north] = bbox;
  return new LngLatBounds([west, south, east, north]);
}

function useHoveredFeature() {
  const { features } = useFeatureCollection();
  const [hovered, setHovered] = useState<Hovered | null>(null);

  const onMouseMove = (event: MapLayerMouseEvent) => {
    const id = event.features?.at(0)?.properties.id;
    if (id == hovered?.id) {
      return;
    }
    // The features of the event are cut along the tiles: the geometry is only
    // whole on our own feature.
    const feature = features.find((feature) => feature.properties?.id == id);
    if (feature?.properties?.description) {
      const { lng, lat } =
        feature.geometry.type == 'LineString' ||
        feature.geometry.type == 'MultiLineString'
          ? event.lngLat
          : getBounds(feature.geometry).getCenter();
      setHovered({
        id,
        description: feature.properties.description,
        longitude: lng,
        latitude: lat
      });
    } else {
      setHovered(null);
    }
  };
  const onMouseLeave = () => setHovered(null);

  return [hovered, onMouseMove, onMouseLeave] as const;
}

function getParcellesSource(
  layers: Record<string, { enabled: boolean }>
): ParcellesSource | undefined {
  if (layers.cadastres?.enabled) {
    return 'cadastre';
  }
  if (layers.rpg?.enabled) {
    return 'rpg';
  }
}

function UnsupportedBrowser() {
  return (
    <div
      style={{ marginBottom: '20px' }}
      className="outdated-browser-banner site-banner"
    >
      <div className="container">
        <div className="site-banner-icon">⚠️</div>
        <div className="site-banner-text">
          <Trans>
            Nous ne pouvons pas afficher la carte car elle est incompatible avec
            votre navigateur. Nous vous conseillons de le mettre à jour ou
            d’utiliser{' '}
            <a
              href="https://browser-update.org/fr/update.html"
              target="_blank"
              rel="noopener noreferrer"
            >
              un navigateur plus récent
            </a>
            .
          </Trans>
        </div>
      </div>
    </div>
  );
}

function isWebglSupported() {
  try {
    const context = document.createElement('canvas').getContext('webgl2');
    // Browsers only grant a handful of contexts: hand this one back.
    context?.getExtension('WEBGL_lose_context')?.loseContext();
    return context != null;
  } catch {
    return false;
  }
}
