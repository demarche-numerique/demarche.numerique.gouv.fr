import { useCallback, useEffect, useMemo } from 'react';
import { Popup, type LngLatBoundsLike, type LngLatLike } from 'maplibre-gl';
import type { Feature, FeatureCollection, Point } from 'geojson';

import { useMapLibre } from '../../shared/maplibre/MapLibre';
import {
  useFitBounds,
  useEvent,
  type EventHandler,
  useMapEvent,
  useFlyTo
} from '../../shared/maplibre/hooks';
import {
  filterFeatureCollection,
  findFeature,
  getBounds,
  getCenter,
  filterFeatureCollectionByGeometryType
} from '../../shared/maplibre/utils';

export function GeoJSONLayer({
  featureCollection
}: {
  featureCollection: FeatureCollection;
}) {
  const map = useMapLibre();
  const popup = useMemo(
    () =>
      new Popup({
        closeButton: false,
        closeOnClick: false
      }),
    []
  );

  const onMouseEnter = useCallback<EventHandler>(
    (event) => {
      const feature = event.features && event.features[0];
      if (feature?.properties && feature.properties.description) {
        const coordinates = getCenter(feature.geometry, event.lngLat);
        const description = feature.properties.description;
        map.getCanvas().style.cursor = 'pointer';
        popup.setLngLat(coordinates).setText(description).addTo(map);
      } else {
        popup.remove();
      }
    },
    [map, popup]
  );

  const onMouseLeave = useCallback(() => {
    map.getCanvas().style.cursor = '';
    popup.remove();
  }, [map, popup]);

  useExternalEvents(featureCollection);

  const polygons = filterFeatureCollectionByGeometryType(
    filterFeatureCollection(featureCollection, 'selection_utilisateur'),
    'Polygon'
  );
  const lines = filterFeatureCollectionByGeometryType(
    filterFeatureCollection(featureCollection, 'selection_utilisateur'),
    'LineString'
  );
  const points = filterFeatureCollectionByGeometryType(
    filterFeatureCollection(featureCollection, 'selection_utilisateur'),
    'Point'
  );

  return (
    <>
      {polygons.features.map((feature) => (
        <PolygonLayer
          key={feature.properties?.id}
          feature={feature}
          onMouseEnter={onMouseEnter}
          onMouseLeave={onMouseLeave}
        />
      ))}
      {lines.features.map((feature) => (
        <LineStringLayer
          key={feature.properties?.id}
          feature={feature}
          onMouseEnter={onMouseEnter}
          onMouseLeave={onMouseLeave}
        />
      ))}
      {points.features.map((feature) => (
        <PointLayer
          key={feature.properties?.id}
          feature={feature}
          onMouseEnter={onMouseEnter}
          onMouseLeave={onMouseLeave}
        />
      ))}
    </>
  );
}

function useExternalEvents(featureCollection: FeatureCollection) {
  const fitBounds = useFitBounds();
  const flyTo = useFlyTo();
  const onFeatureFocus = useCallback(
    ({ detail }: CustomEvent<{ id: string }>) => {
      const { id } = detail;
      const feature = findFeature(featureCollection, id);
      if (feature) {
        fitBounds(getBounds(feature.geometry));
      }
    },
    [featureCollection, fitBounds]
  );
  const onZoomFocus = useCallback(
    ({ detail }: CustomEvent<{ feature: Feature<Point> }>) => {
      const { feature } = detail;
      if (feature) {
        flyTo(17, feature.geometry.coordinates as LngLatLike);
      }
    },
    [flyTo]
  );

  useEffect(() => {
    fitBounds(featureCollection.bbox as LngLatBoundsLike);
    // We only want to zoom on bbox on component mount.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fitBounds]);

  useEvent('map:feature:focus', onFeatureFocus);
  useEvent('map:zoom', onZoomFocus);
}

function LineStringLayer({
  feature,
  onMouseEnter,
  onMouseLeave
}: {
  feature: Feature;
  onMouseEnter: EventHandler;
  onMouseLeave: EventHandler;
}) {
  const map = useMapLibre();
  const sourceId = String(feature.properties?.id);
  const layerId = `${sourceId}-layer`;

  const render = () => {
    if (!map.getSource(sourceId)) {
      map
        .addSource(sourceId, {
          type: 'geojson',
          data: feature
        })
        .addLayer({
          id: layerId,
          source: sourceId,
          type: 'line',
          paint: lineStringSelectionLine
        });
    }
  };

  useEffect(render, [map, layerId, sourceId, feature]);
  useMapEvent('styledata', render);
  useMapEvent('mouseenter', onMouseEnter, layerId);
  useMapEvent('mouseleave', onMouseLeave, layerId);

  return null;
}

function PointLayer({
  feature,
  onMouseEnter,
  onMouseLeave
}: {
  feature: Feature;
  onMouseEnter: EventHandler;
  onMouseLeave: EventHandler;
}) {
  const map = useMapLibre();
  const sourceId = String(feature.properties?.id);
  const layerId = `${sourceId}-layer`;

  const render = () => {
    if (!map.getSource(sourceId)) {
      map
        .addSource(sourceId, {
          type: 'geojson',
          data: feature
        })
        .addLayer({
          id: layerId,
          source: sourceId,
          type: 'circle',
          paint: pointSelectionCircle
        });
    }
  };

  useEffect(render, [map, layerId, sourceId, feature]);
  useMapEvent('styledata', render);
  useMapEvent('mouseenter', onMouseEnter, layerId);
  useMapEvent('mouseleave', onMouseLeave, layerId);

  return null;
}

function PolygonLayer({
  feature,
  onMouseEnter,
  onMouseLeave
}: {
  feature: Feature;
  onMouseEnter: EventHandler;
  onMouseLeave: EventHandler;
}) {
  const map = useMapLibre();
  const sourceId = String(feature.properties?.id);
  const layerId = `${sourceId}-layer`;
  const lineLayerId = `${sourceId}-line-layer`;

  const render = () => {
    if (!map.getSource(sourceId)) {
      map
        .addSource(sourceId, {
          type: 'geojson',
          data: feature
        })
        .addLayer({
          id: lineLayerId,
          source: sourceId,
          type: 'line',
          paint: polygonSelectionLine
        })
        .addLayer({
          id: layerId,
          source: sourceId,
          type: 'fill',
          paint: polygonSelectionFill
        });
    }
  };

  useEffect(render, [map, layerId, lineLayerId, sourceId, feature]);
  useMapEvent('styledata', render);
  useMapEvent('mouseenter', onMouseEnter, layerId);
  useMapEvent('mouseleave', onMouseLeave, layerId);

  return null;
}

const polygonSelectionFill = {
  'fill-color': '#EC3323',
  'fill-opacity': 0.5
};
const polygonSelectionLine = {
  'line-color': 'rgba(255, 0, 0, 1)',
  'line-width': 4
};
const lineStringSelectionLine = {
  'line-color': 'rgba(55, 42, 127, 1.00)',
  'line-width': 3
};
const pointSelectionCircle = {
  'circle-color': '#EC3323'
};
