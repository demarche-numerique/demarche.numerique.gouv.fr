import {
  useEffect,
  useEffectEvent,
  useLayoutEffect,
  useMemo,
  useState
} from 'react';
import type { Feature } from 'geojson';
import type { Map as MapLibreMap } from 'maplibre-gl';
import { useLingui } from '@lingui/react/macro';
import {
  TerraDraw,
  TerraDrawLineStringMode,
  TerraDrawPointMode,
  TerraDrawPolygonMode,
  TerraDrawRectangleMode,
  TerraDrawSelectMode,
  ValidateNotSelfIntersecting,
  type GeoJSONStoreFeatures
} from 'terra-draw';
import { TerraDrawMapLibreGLAdapter } from 'terra-draw-maplibre-gl-adapter';

import { ANCHORS } from '../shared/maplibre/styles';
import { useMapLibre } from './MapLibreProvider';
import { useMapStyleId } from './hooks';
import { PortalControl } from './PortalControl';
import {
  COORDINATE_PRECISION,
  isDrawable,
  planSync,
  serializeGeometry,
  type DrawableGeometry
} from './draw';
import './DrawLayer.css';

export type DrawMode =
  'select' | 'point' | 'linestring' | 'polygon' | 'rectangle';

export type DrawnFeature = Feature<DrawableGeometry> & { id: string };

// A Terra Draw instance lives as long as a basemap: its layers are not part of
// the map style, and a new style would remove them under its feet.
type Session = {
  draw: TerraDraw;
  // The geometry of every feature Terra Draw holds, serialized, by id.
  drawn: Map<string, string>;
};

export function DrawLayer({
  features,
  onCreate,
  onUpdate,
  onDelete
}: {
  features: Feature[];
  onCreate: (feature: DrawnFeature) => void;
  onUpdate: (id: string, geometry: DrawableGeometry) => void;
  onDelete: (id: string) => void;
}) {
  const { t } = useLingui();
  const map = useMapLibre();
  const styleId = useMapStyleId();
  const [session, setSession] = useState<Session | null>(null);
  const [mode, setMode] = useState<DrawMode>('select');
  const [selected, setSelected] = useState<string | null>(null);
  const drawable = useMemo(() => features.filter(isDrawable), [features]);

  const onFinish = useEffectEvent(
    ({ draw, drawn }: Session, id: string, action: string) => {
      const feature = draw.getSnapshotFeature(id);
      if (!feature) {
        return;
      }
      const geometry = feature.geometry as DrawableGeometry;
      drawn.set(id, serializeGeometry(geometry));
      if (action == 'draw') {
        onCreate({ type: 'Feature', id, geometry, properties: {} });
        setMode('select');
      } else {
        onUpdate(id, geometry);
      }
    }
  );

  const onRemoved = useEffectEvent(({ drawn }: Session, ids: string[]) => {
    // Only the features of the usager count: Terra Draw also removes the
    // handles it draws around a selection.
    for (const id of ids) {
      if (drawn.delete(id)) {
        onDelete(id);
      }
    }
  });

  useLayoutEffect(() => {
    const instance = map?.getMap();
    if (!instance) {
      return;
    }
    let current: Session | undefined;
    const start = () => {
      const draw = createTerraDraw(instance);
      const session: Session = { draw, drawn: new Map() };
      draw.on('finish', (id, { action }) =>
        onFinish(session, String(id), action)
      );
      draw.on('change', (ids, type) => {
        if (type == 'delete') {
          onRemoved(session, ids.map(String));
        }
      });
      draw.on('select', (id) => setSelected(String(id)));
      draw.on('deselect', () => setSelected(null));
      draw.start();
      current = session;
      setSession(session);
    };
    // A layout effect, so that the cleanup runs before the canvas applies a
    // new basemap, while the layers of Terra Draw are still on the map.
    const cancel = whenStyleLoaded(instance, start);

    return () => {
      cancel();
      current?.draw.stop();
      setSession(null);
      setSelected(null);
    };
  }, [map, styleId]);

  // Terra Draw shows the features it is given, whoever changed them.
  useEffect(() => {
    if (!session) {
      return;
    }
    const { draw, drawn } = session;
    const { add, update, remove } = planSync(drawn, drawable);

    for (const id of remove) {
      drawn.delete(id);
    }
    if (remove.length > 0) {
      draw.removeFeatures(remove);
    }
    for (const [id, geometry] of update) {
      drawn.set(id, serializeGeometry(geometry));
      draw.updateFeatureGeometry(id, geometry);
    }
    addFeatures(session, add);
  }, [session, drawable]);

  useEffect(() => {
    session?.draw.setMode(mode);
  }, [session, mode]);

  const deleteSelected = () => {
    if (session && selected) {
      session.draw.deselectFeature(selected);
      session.draw.removeFeatures([selected]);
    }
  };

  const tools: [DrawMode, string, string][] = [
    [
      'select',
      t`Sélectionner et modifier une forme`,
      'fr-icon-drag-move-2-line'
    ],
    ['point', t`Ajouter un point`, 'fr-icon-map-pin-2-line'],
    ['linestring', t`Tracer une ligne`, 'fr-icon-pen-nib-line'],
    ['polygon', t`Dessiner un polygone`, 'fr-icon-pentagon-line'],
    ['rectangle', t`Dessiner un rectangle`, 'fr-icon-square-line']
  ];
  const deleteLabel = t`Supprimer la forme sélectionnée`;

  return (
    <PortalControl position="top-left">
      <div role="group" aria-label={t`Outils de dessin`} className="draw-tools">
        {tools.map(([tool, label, icon]) => (
          <button
            key={tool}
            type="button"
            title={label}
            aria-label={label}
            aria-pressed={mode == tool}
            onClick={() => setMode(tool)}
          >
            <span className={`${icon} fr-icon--sm`} aria-hidden="true" />
          </button>
        ))}
        <button
          type="button"
          title={deleteLabel}
          aria-label={deleteLabel}
          disabled={!selected}
          onClick={deleteSelected}
        >
          <span
            className="fr-icon-delete-bin-line fr-icon--sm"
            aria-hidden="true"
          />
        </button>
      </div>
    </PortalControl>
  );
}

function addFeatures(
  { draw, drawn }: Session,
  features: GeoJSONStoreFeatures[]
) {
  if (features.length == 0) {
    return;
  }
  // A feature Terra Draw refuses (a self-intersecting import, say) is still
  // part of the collection: it is only not editable on the map.
  const results = draw.addFeatures(features);
  for (const [index, { valid }] of results.entries()) {
    const { id, geometry } = features[index];
    if (valid) {
      drawn.set(String(id), serializeGeometry(geometry));
    }
  }
}

function whenStyleLoaded(map: MapLibreMap, callback: () => void) {
  // Wait a frame: the canvas applies a new basemap after this layout effect.
  const frame = requestAnimationFrame(() => {
    if (isStyleLoaded(map)) {
      callback();
    } else {
      map.once('style.load', callback);
    }
  });
  return () => {
    cancelAnimationFrame(frame);
    map.off('style.load', callback);
  };
}

// Whether the style itself is in, tiles aside: `map.isStyleLoaded()` also
// waits for every source, which may never happen offline. react-maplibre reads
// the same private flag.
function isStyleLoaded(map: MapLibreMap) {
  return (map as unknown as { style?: { _loaded?: boolean } }).style?._loaded;
}

const COLORS = {
  fill: '#EC3323',
  outline: '#FF0000',
  line: '#372A7F',
  selected: '#000091',
  handle: '#FFFFFF'
} as const;

const SNAPPING = { toCoordinate: true, toLine: true };

// Checked when a shape is finished, not while the usager is moving the mouse.
function notSelfIntersecting(
  feature: GeoJSONStoreFeatures,
  { updateType }: { updateType: unknown }
) {
  return String(updateType) == 'provisional'
    ? { valid: true }
    : ValidateNotSelfIntersecting(feature);
}

function createTerraDraw(map: MapLibreMap) {
  const editable = {
    feature: {
      draggable: true,
      validation: notSelfIntersecting,
      coordinates: {
        draggable: true,
        midpoints: true,
        deletable: true,
        snappable: SNAPPING
      }
    }
  };
  const polygonStyles = {
    fillColor: COLORS.fill,
    fillOpacity: 0.5,
    outlineColor: COLORS.outline,
    outlineWidth: 3
  } as const;

  return new TerraDraw({
    adapter: new TerraDrawMapLibreGLAdapter({
      map,
      renderBelowLayerId: ANCHORS.selections,
      coordinatePrecision: COORDINATE_PRECISION
    }),
    // Our ids: the uuids of the geo areas, and a new one for a new shape.
    idStrategy: {
      isValidId: (id) => typeof id == 'string' && id.length > 0,
      getId: () => crypto.randomUUID()
    },
    // No createdAt / updatedAt in the properties.
    tracked: false,
    modes: [
      new TerraDrawSelectMode({
        flags: {
          point: { feature: { draggable: true } },
          linestring: editable,
          polygon: editable,
          rectangle: editable
        },
        styles: {
          selectedPointColor: COLORS.selected,
          selectedLineStringColor: COLORS.selected,
          selectedPolygonColor: COLORS.selected,
          selectedPolygonOutlineColor: COLORS.selected,
          selectionPointColor: COLORS.handle,
          selectionPointOutlineColor: COLORS.selected,
          selectionPointOutlineWidth: 2,
          midPointColor: COLORS.handle,
          midPointOutlineColor: COLORS.selected,
          midPointOutlineWidth: 1
        }
      }),
      new TerraDrawPointMode({
        styles: {
          pointColor: COLORS.fill,
          pointWidth: 6,
          pointOutlineColor: COLORS.handle,
          pointOutlineWidth: 2
        }
      }),
      new TerraDrawLineStringMode({
        snapping: SNAPPING,
        styles: { lineStringColor: COLORS.line, lineStringWidth: 3 }
      }),
      new TerraDrawPolygonMode({
        snapping: SNAPPING,
        validation: notSelfIntersecting,
        styles: polygonStyles
      }),
      new TerraDrawRectangleMode({ styles: polygonStyles })
    ]
  });
}
