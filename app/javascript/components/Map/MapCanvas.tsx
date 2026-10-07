import { useRef, useState } from 'react';
import type { Feature } from 'geojson';
import {
  Map,
  NavigationControl,
  Popup,
  type MapLayerMouseEvent
} from '@vis.gl/react-maplibre';
import { LngLatBounds, type MapGeoJSONFeature } from 'maplibre-gl';
import { Trans } from '@lingui/react/macro';
import invariant from 'tiny-invariant';

import { StyleSwitch } from '../shared/maplibre/StyleControl';
import { useMapId } from './MapLibreProvider';
import { useFeatureCollection } from './FeatureCollectionProvider';
import { PortalControl } from './PortalControl';
import { AttributionControl } from './AttributionControl';
import { OptionalLayers } from './OptionalLayers';
import { SelectionsLayer, SELECTIONS_LAYERS } from './SelectionsLayer';
import { useElementVisible, useMapStyle } from './hooks';
import { getBounds } from './geometry';
import { getMaxZoom } from './camera';
import {
  isParcelleSource,
  parcelleInfo,
  tileParcelleId,
  useParcelleLabel
} from './parcelle';
import './Popup.css';

// maplibre-gl 6 requires WebGL2: a WebGL1-only browser must get our banner,
// not maplibre's own error.
const webglSupported = isWebglSupported();

// The parcelles of the dossier are those of the tiles, highlighted.
const PARCELLE_HIGHLIGHTED_LAYER = 'parcelle-highlighted';
const INTERACTIVE_LAYERS = [...SELECTIONS_LAYERS, PARCELLE_HIGHLIGHTED_LAYER];

type Hovered = {
  id: string;
  lines: string[];
  longitude: number;
  latitude: number;
};

export function MapCanvas({ layers }: { layers: string[] }) {
  const mapId = useMapId();
  const bounds = useBounds();
  const containerRef = useRef<HTMLDivElement>(null);
  const visible = useElementVisible(containerRef);
  const { style, layers: optionalLayers, ...styleProps } = useMapStyle(layers);
  const [hovered, onMouseMove, onMouseLeave] = useHoveredFeature();

  if (!webglSupported) {
    return <UnsupportedBrowser />;
  }

  return (
    <div ref={containerRef} style={{ height: '500px' }}>
      {visible ? (
        <Map
          id={mapId}
          mapStyle={style}
          initialViewState={{
            bounds,
            fitBoundsOptions: { padding: 100, maxZoom: getMaxZoom(bounds) }
          }}
          attributionControl={false}
          interactiveLayerIds={INTERACTIVE_LAYERS}
          cursor={hovered ? 'pointer' : undefined}
          onMouseMove={onMouseMove}
          onMouseLeave={onMouseLeave}
          // Leaving the map over a shape is not leaving the shape.
          onMouseOut={onMouseLeave}
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
          {hovered ? (
            <Popup
              longitude={hovered.longitude}
              latitude={hovered.latitude}
              closeButton={false}
              closeOnClick={false}
              className="map-popup"
            >
              {hovered.lines.map((line, index) => (
                <div key={index}>{line}</div>
              ))}
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
  const parcelleLabel = useParcelleLabel();

  // A parcelle tells what it is, and every feature its description.
  const describe = (feature: Feature) => {
    const parcelle = parcelleInfo(feature.properties);
    return [
      parcelle ? parcelleLabel(parcelle) : null,
      feature.properties?.description
    ].filter(Boolean);
  };

  const onMouseMove = (event: MapLayerMouseEvent) => {
    const target = event.features?.at(0);
    // The features of the event are cut along the tiles: the geometry is only
    // whole on our own feature.
    const feature = target ? findFeature(features, target) : undefined;
    const id = feature?.properties?.id;
    if (id == hovered?.id) {
      return;
    }
    const lines = feature ? describe(feature) : [];
    if (feature && lines.length > 0) {
      const { lng, lat } =
        feature.geometry.type == 'LineString' ||
        feature.geometry.type == 'MultiLineString'
          ? event.lngLat
          : getBounds(feature.geometry).getCenter();
      setHovered({
        id,
        lines,
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

function findFeature(features: Feature[], target: MapGeoJSONFeature) {
  if (target.layer.id == PARCELLE_HIGHLIGHTED_LAYER) {
    const cid = tileParcelleId(target);
    return features.find(
      ({ properties }) =>
        isParcelleSource(properties?.source) && properties?.cid == cid
    );
  }
  return features.find(
    ({ properties }) => properties?.id == target.properties.id
  );
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
