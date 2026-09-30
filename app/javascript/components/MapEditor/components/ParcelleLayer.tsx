import { useCallback, useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import type { Feature, FeatureCollection } from 'geojson';

import { useMapLibre, ReactControl } from '../../shared/maplibre/MapLibre';
import { PARCELLE_LAYERS } from '../../shared/maplibre/styles';
import {
  useEvent,
  useMapEvent,
  type EventHandler
} from '../../shared/maplibre/hooks';
import {
  filterFeatureCollection,
  findFeature
} from '../../shared/maplibre/utils';

import { type CreateFeatures, type DeleteFeatures } from '../hooks';

export function ParcelleLayer({
  source,
  featureCollection,
  createFeatures,
  deleteFeatures,
  toggle,
  enabled
}: {
  source: 'rpg' | 'cadastre';
  featureCollection: FeatureCollection;
  createFeatures: CreateFeatures;
  deleteFeatures: DeleteFeatures;
  toggle: () => void;
  enabled: boolean;
}) {
  const map = useMapLibre();
  const selectedParcellesRef = useRef(new Set<string>());
  const [controlElement, setControlElement] = useState<HTMLElement | null>(
    null
  );
  const cidProperty = Object.values(PARCELLE_LAYERS).find(
    (layer) => layer.source == source
  )!.idProperty;

  useEffect(() => {
    const control = new ReactControl();
    map.addControl(control, 'top-left');
    // Syncing the imperatively-created control's container into state is the
    // intended pattern here; the container only exists after addControl.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setControlElement(control.container);

    return () => {
      map.removeControl(control);
      setControlElement(null);
    };
  }, [map, enabled]);

  const highlightFeature = useCallback(
    (cid: string, highlight: boolean) => {
      if (highlight) {
        selectedParcellesRef.current.add(cid);
      } else {
        selectedParcellesRef.current.delete(cid);
      }
      if (selectedParcellesRef.current.size == 0) {
        map.setFilter('parcelle-highlighted', ['in', cidProperty, '']);
      } else {
        map.setFilter('parcelle-highlighted', [
          'in',
          cidProperty,
          ...selectedParcellesRef.current
        ]);
      }
    },
    [map, cidProperty]
  );

  const hoverFeature = useCallback(
    (feature: Feature, hover: boolean) => {
      if (!selectedParcellesRef.current.has(feature.properties?.id)) {
        map.setFeatureState(
          {
            source,
            sourceLayer: 'parcelles',
            id: String(feature.id)
          },
          { hover }
        );
      }
    },
    [map, source]
  );

  useParcelles(featureCollection, {
    source,
    hoverFeature,
    createFeatures,
    deleteFeatures,
    enabled
  });

  useMapEvent('styledata', () => {
    selectedParcellesRef.current = new Set(
      filterFeatureCollection(featureCollection, source).features.map(
        ({ properties }) => properties?.cid
      )
    );
    if (selectedParcellesRef.current.size > 0) {
      map.setFilter('parcelle-highlighted', [
        'in',
        cidProperty,
        ...selectedParcellesRef.current
      ]);
    }
  });

  const onHighlight = useCallback(
    ({ detail }: CustomEvent<{ cid: string; highlight: boolean }>) => {
      highlightFeature(detail.cid, detail.highlight);
    },
    [highlightFeature]
  );

  useEvent('map:internal:parcelle:highlight', onHighlight);

  return (
    <>
      {controlElement != null
        ? createPortal(
            <ParcelleSwitch enabled={enabled} toggle={toggle} />,
            controlElement
          )
        : null}
    </>
  );
}

function ParcelleSwitch({
  enabled,
  toggle
}: {
  enabled: boolean;
  toggle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={toggle}
      title="Sélectionner les parcelles"
      className={enabled ? 'on' : 'off'}
    >
      <span className="fr-icon-cursor-line fr-icon--sm" aria-hidden="true" />
    </button>
  );
}

function useParcelles(
  featureCollection: FeatureCollection,
  {
    source,
    enabled,
    hoverFeature,
    createFeatures,
    deleteFeatures
  }: {
    enabled: boolean;
    source: 'rpg' | 'cadastre';
    hoverFeature: (feature: Feature, flag: boolean) => void;
    createFeatures: CreateFeatures;
    deleteFeatures: DeleteFeatures;
  }
) {
  const hoveredFeature = useRef<Feature>(null);

  const onMouseMove = useCallback<EventHandler>(
    (event) => {
      if (enabled && event.features && event.features.length > 0) {
        const feature = event.features[0];
        if (hoveredFeature.current?.id != feature.id) {
          if (hoveredFeature.current) {
            hoverFeature(hoveredFeature.current, false);
          }
          hoveredFeature.current = feature;
          hoverFeature(feature, true);
        }
      }
    },
    [enabled, hoverFeature]
  );

  const onMouseLeave = useCallback<EventHandler>(() => {
    if (hoveredFeature.current) {
      hoverFeature(hoveredFeature.current, false);
    }
    hoveredFeature.current = null;
  }, [hoverFeature]);

  const onClick = useCallback<EventHandler>(
    async (event) => {
      if (enabled && event.features && event.features.length > 0) {
        for (const feature of event.features) {
          if (feature.properties?.ID_PARCEL) {
            feature.properties.id = feature.properties.ID_PARCEL;
          }
        }
        const currentId = event.features[0].properties?.id;
        const feature = findFeature(
          filterFeatureCollection(featureCollection, source),
          currentId,
          'cid'
        );
        if (feature) {
          deleteFeatures({
            features: [feature],
            source,
            external: true
          });
        } else {
          createFeatures({
            features: event.features,
            source,
            external: true
          });
        }
      }
    },
    [enabled, source, featureCollection, createFeatures, deleteFeatures]
  );

  useMapEvent('click', onClick, 'parcelles-fill');
  useMapEvent('mousemove', onMouseMove, 'parcelles-fill');
  useMapEvent('mouseleave', onMouseLeave, 'parcelles-fill');
}
