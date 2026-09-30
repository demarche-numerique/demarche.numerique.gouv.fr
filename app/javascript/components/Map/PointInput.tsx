import { useId, useState } from 'react';
import { useLingui } from '@lingui/react/macro';
import type { Point } from 'geojson';
import CoordinateInput from 'react-coordinate-input';

import { useMapLibre } from './MapLibreProvider';
import { useFeatureActions } from './FeatureCollectionProvider';
import { fitGeometry } from './camera';

// Adds a point from its coordinates, or from the position of the usager.
export function PointInput() {
  const { t } = useLingui();
  const inputId = useId();
  const map = useMapLibre();
  const actions = useFeatureActions();
  const [value, setValue] = useState('');
  const [point, setPoint] = useState<Point | null>(null);

  if (!actions) {
    return null;
  }

  const getCurrentPosition = () => {
    navigator.geolocation?.getCurrentPosition(({ coords }) => {
      setValue(
        `${coords.latitude.toPrecision(6)}, ${coords.longitude.toPrecision(6)}`
      );
    });
  };
  const addPoint = () => {
    if (point) {
      actions.create([{ type: 'Feature', geometry: point, properties: {} }]);
      setValue('');
      setPoint(null);
    }
  };
  const showPosition = t`Afficher votre position sur la carte`;
  const add = t`Ajouter le point avec les coordonnées saisies sur la carte`;

  return (
    <div className="fr-input-group fr-mt-3w" data-autosave-ignore>
      <label className="fr-label" htmlFor={inputId}>
        {t`Ajouter un point sur la carte`}
        <span className="fr-hint-text">
          {t`Exemple :`} 43°48&#39;06&#34;N 006°14&#39;59&#34;E
        </span>
      </label>
      <div className="flex flex-gap-1 fr-mt-1w">
        {navigator.geolocation ? (
          <button
            type="button"
            className="fr-btn fr-btn--secondary fr-icon-map-pin-2-line"
            onClick={getCurrentPosition}
            title={showPosition}
          >
            <span className="fr-sr-only">{showPosition}</span>
          </button>
        ) : null}
        <CoordinateInput
          id={inputId}
          className="fr-input"
          value={value}
          onChange={(value: string, { dd }: { dd: [number, number] }) => {
            setValue(value);
            if (dd.length) {
              const point: Point = {
                type: 'Point',
                coordinates: [dd[1], dd[0]]
              };
              setPoint(point);
              if (map) {
                fitGeometry(map, point);
              }
            } else {
              setPoint(null);
            }
          }}
        />
        <button
          type="button"
          className="fr-btn fr-icon-add-circle-line"
          onClick={addPoint}
          disabled={!point}
          title={add}
        >
          <span className="fr-sr-only">{add}</span>
        </button>
      </div>
    </div>
  );
}
