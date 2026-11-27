import { useId, useRef, useEffect } from 'react';
import { Button, Dialog, DialogTrigger, Popover } from 'react-aria-components';
import { useLingui } from '@lingui/react/macro';

import { Slider } from '../../react-aria/components/Slider';
import { type LayersMap, type MapStyle, NBS } from './styles';
import './StyleControl.css';

const WIDE_THRESHOLD = 3;

export function StyleSwitch({
  styleId,
  layers,
  setStyle,
  setLayerEnabled,
  setLayerOpacity
}: {
  styleId: MapStyle;
  setStyle: (style: MapStyle) => void;
  layers: LayersMap;
  setLayerEnabled: (layer: string, enabled: boolean) => void;
  setLayerOpacity: (layer: string, opacity: number) => void;
}) {
  const { t } = useLingui();
  const styles: [MapStyle, string][] = [
    ['ortho', t`Satellite`],
    ['vector', t`Vectoriel`],
    ['ign', t`Carte IGN`]
  ];
  const configurableLayers = Object.entries(layers).filter(
    ([, { configurable }]) => configurable
  );
  // A long list of layers is laid out in two columns.
  const wide = configurableLayers.length > WIDE_THRESHOLD;
  const mapId = useId();
  const buttonRef = useRef<HTMLButtonElement>(null);
  const title = t`Sélectionner les couches cartographiques`;

  useEffect(() => {
    if (buttonRef.current) {
      buttonRef.current.title = title;
    }
  }, [title]);

  return (
    <DialogTrigger>
      <Button ref={buttonRef} aria-label={title}>
        <span
          className="fr-icon-road-map-line fr-icon--sm"
          aria-hidden="true"
        />
      </Button>
      <Popover
        className={`react-aria-Popover map-layers-popover ${wide ? 'map-layers-popover--wide' : ''}`}
        placement="top start"
        offset={8}
      >
        <Dialog className="map-layers" aria-label={t`Couches cartographiques`}>
          <fieldset
            className="fr-fieldset"
            aria-labelledby={`${mapId}-styles-legend`}
          >
            <legend
              className="fr-fieldset__legend fr-text--bold"
              id={`${mapId}-styles-legend`}
            >
              {t`Fond de carte`}
            </legend>
            {styles.map(([style, title]) => (
              <div
                className="fr-fieldset__element fr-fieldset__element--inline"
                key={style}
              >
                <div className="fr-radio-group fr-radio-group--sm">
                  <input
                    id={`${mapId}-${style}`}
                    value={style}
                    type="radio"
                    name={`${mapId}-style`}
                    checked={styleId == style}
                    onChange={() => setStyle(style)}
                  />
                  <label htmlFor={`${mapId}-${style}`} className="fr-label">
                    {title}
                  </label>
                </div>
              </div>
            ))}
          </fieldset>
          {configurableLayers.length ? (
            <fieldset
              className="fr-fieldset"
              aria-labelledby={`${mapId}-layers-legend`}
            >
              <legend
                className="fr-fieldset__legend fr-text--bold"
                id={`${mapId}-layers-legend`}
              >
                {t`Couches`}
              </legend>
              {configurableLayers.map(([layer, { enabled, opacity, name }]) => (
                <div key={layer} className="fr-fieldset__element">
                  <div className="fr-checkbox-group fr-checkbox-group--sm">
                    <input
                      id={`${mapId}-${layer}`}
                      type="checkbox"
                      checked={enabled}
                      onChange={(event) => {
                        setLayerEnabled(layer, event.target.checked);
                      }}
                    />
                    <label className="fr-label" htmlFor={`${mapId}-${layer}`}>
                      {/* The names come with non-breaking spaces only: let the longer ones wrap. */}
                      {name.replace(/\s/g, ' ')}
                    </label>
                  </div>
                  <Slider
                    minValue={10}
                    maxValue={100}
                    step={5}
                    value={opacity}
                    isDisabled={!enabled}
                    onChange={(value) => {
                      setLayerOpacity(layer, value);
                    }}
                    className="react-aria-Slider"
                    aria-label={t`Réglage de l’opacité de la couche «${NBS}${name}${NBS}»`}
                  />
                </div>
              ))}
            </fieldset>
          ) : null}
        </Dialog>
      </Popover>
    </DialogTrigger>
  );
}
