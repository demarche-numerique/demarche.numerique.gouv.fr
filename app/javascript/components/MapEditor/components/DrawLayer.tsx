import { useCallback, useRef, useEffect } from 'react';
import type { LngLatBoundsLike, LngLatLike, IControl } from 'maplibre-gl';
import DrawControl from '@mapbox/mapbox-gl-draw';
import type { FeatureCollection, Feature, Point } from 'geojson';

import { useMapLibre } from '../../shared/maplibre/MapLibre';
import {
  useFitBounds,
  useFitBoundsNoFly,
  useEvent,
  useMapEvent,
  useFlyTo
} from '../../shared/maplibre/hooks';
import {
  filterFeatureCollection,
  findFeature,
  getBounds
} from '../../shared/maplibre/utils';
import {
  SOURCE_SELECTION_UTILISATEUR,
  type CreateFeatures,
  type UpdateFatures,
  type DeleteFeatures
} from '../hooks';

export function DrawLayer({
  featureCollection,
  createFeatures,
  updateFeatures,
  deleteFeatures,
  enabled
}: {
  featureCollection: FeatureCollection;
  createFeatures: CreateFeatures;
  updateFeatures: UpdateFatures;
  deleteFeatures: DeleteFeatures;
  enabled: boolean;
}) {
  const map = useMapLibre();
  const drawRef = useRef<DrawControl | null>(null);

  useEffect(() => {
    if (!drawRef.current && enabled) {
      const draw = new DrawControl({
        displayControlsDefault: false,
        controls: {
          point: true,
          line_string: true,
          polygon: true,
          trash: true
        }
      });
      // We use mapbox-draw plugin with maplibre. They are compatible but types are not.
      const control = draw as unknown as IControl;
      map.addControl(control, 'top-left');
      draw.set(
        filterFeatureCollection(featureCollection, SOURCE_SELECTION_UTILISATEUR)
      );
      drawRef.current = draw;

      patchDrawControl();
    }

    return () => {
      if (drawRef.current) {
        // We use mapbox-draw plugin with maplibre. They are compatible but types are not.
        map.removeControl(drawRef.current as unknown as IControl);
        drawRef.current = null;
      }
    };
    // We only want to rerender draw layer on component mount or when the layer is toggled.
    // oxlint-disable-next-line react-hooks/exhaustive-deps
  }, [map, enabled]);

  const onSetId = useCallback(
    ({ detail }: CustomEvent<{ lid: string; id: string }>) => {
      drawRef.current?.setFeatureProperty(detail.lid, 'id', detail.id);
    },
    []
  );
  const onAddFeature = useCallback(
    ({ detail }: CustomEvent<{ feature: Feature }>) => {
      drawRef.current?.add(detail.feature);
    },
    []
  );
  const onDeleteFature = useCallback(
    ({ detail }: CustomEvent<{ id: string }>) => {
      drawRef.current?.delete(detail.id);
    },
    []
  );

  useMapEvent('draw.create', createFeatures);
  useMapEvent('draw.update', updateFeatures);
  useMapEvent('draw.delete', deleteFeatures);

  useEvent('map:internal:draw:setId', onSetId);
  useEvent('map:internal:draw:add', onAddFeature);
  useEvent('map:internal:draw:delete', onDeleteFature);

  useExternalEvents(featureCollection, {
    createFeatures,
    updateFeatures,
    deleteFeatures
  });

  return null;
}

function useExternalEvents(
  featureCollection: FeatureCollection,
  {
    createFeatures,
    updateFeatures,
    deleteFeatures
  }: {
    createFeatures: CreateFeatures;
    updateFeatures: UpdateFatures;
    deleteFeatures: DeleteFeatures;
  }
) {
  const fitBounds = useFitBounds();
  const fitBoundsNoFly = useFitBoundsNoFly();
  const flyTo = useFlyTo();

  const onFeatureFocus = useCallback(
    ({ detail }: CustomEvent<{ id: string; bbox: LngLatBoundsLike }>) => {
      const { id, bbox } = detail;
      if (id) {
        const feature = findFeature(featureCollection, id);
        if (feature) {
          fitBounds(getBounds(feature.geometry));
        }
      } else if (bbox) {
        fitBounds(bbox);
      }
    },
    [featureCollection, fitBounds]
  );

  const onZoomFocus = useCallback(
    ({
      detail
    }: CustomEvent<{
      feature: Feature<Point>;
      featureCollection: FeatureCollection;
    }>) => {
      if (detail.feature && detail.featureCollection == featureCollection) {
        flyTo(17, detail.feature.geometry.coordinates as LngLatLike);
      }
    },
    [flyTo, featureCollection]
  );

  const onFeatureCreate = useCallback(
    ({
      detail
    }: CustomEvent<{
      feature: Feature;
      featureCollection: FeatureCollection;
    }>) => {
      const { feature } = detail;
      const { geometry, properties } = feature;
      if (
        feature &&
        feature.geometry &&
        detail.featureCollection == featureCollection
      ) {
        createFeatures({
          features: [{ type: 'Feature', geometry, properties }],
          external: true
        });
      }
    },
    [createFeatures, featureCollection]
  );

  const onFeatureUpdate = useCallback(
    ({
      detail
    }: CustomEvent<{ id: string; properties: Feature['properties'] }>) => {
      const { id, properties } = detail;
      const feature = findFeature(featureCollection, id);

      if (feature) {
        feature.properties = { ...feature.properties, ...properties };
        updateFeatures({ features: [feature], external: true });
      }
    },
    [featureCollection, updateFeatures]
  );

  const onFeatureDelete = useCallback(
    ({ detail }: CustomEvent<{ id: string }>) => {
      const { id } = detail;
      const feature = findFeature(featureCollection, id);

      if (feature) {
        deleteFeatures({ features: [feature], external: true });
      }
    },
    [featureCollection, deleteFeatures]
  );

  useEffect(() => {
    fitBoundsNoFly(featureCollection.bbox as LngLatBoundsLike);
    // We only want to zoom on bbox on component mount.
    // oxlint-disable-next-line react-hooks/exhaustive-deps
  }, [fitBoundsNoFly]);

  useEvent('map:feature:focus', onFeatureFocus);
  useEvent('map:feature:create', onFeatureCreate);
  useEvent('map:feature:update', onFeatureUpdate);
  useEvent('map:feature:delete', onFeatureDelete);
  useEvent('map:zoom', onZoomFocus);
}

const translations = [
  ['.mapbox-gl-draw_line', 'Tracer une ligne'],
  ['.mapbox-gl-draw_polygon', 'Dessiner un polygone'],
  ['.mapbox-gl-draw_point', 'Ajouter un point'],
  ['.mapbox-gl-draw_trash', 'Supprimer']
];

function patchDrawControl() {
  document.querySelectorAll('.mapboxgl-ctrl').forEach((control) => {
    control.classList.add('maplibregl-ctrl', 'maplibregl-ctrl-group');

    for (const [selector, translation] of translations) {
      for (const button of control.querySelectorAll(selector)) {
        button.setAttribute('title', translation);
      }
    }
  });
}
