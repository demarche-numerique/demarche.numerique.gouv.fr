import { useMemo } from 'react';
import { useLingui } from '@lingui/react/macro';
import type { Feature } from 'geojson';

import { RemoteComboBox } from '../ComboBox';
import { createLoader } from '../react-aria/hooks';
import { useMapLibre } from './MapLibreProvider';
import { fitGeometry } from './camera';

// Centers the map on an address: nothing is added to the collection.
export function AddressInput({
  source,
  id,
  ariaLabelledbyPrefix
}: {
  source: string;
  id: string;
  ariaLabelledbyPrefix?: string;
}) {
  const { t } = useLingui();
  const map = useMapLibre();
  const errorMessage = t`Une erreur est survenue lors de la recherche d’adresse`;
  const loader = useMemo(
    () => createLoader(source, { minimumInputLength: 2, errorMessage }),
    [source, errorMessage]
  );

  return (
    <div className="fr-mb-2w" data-autosave-ignore>
      <RemoteComboBox
        minimumInputLength={2}
        id={id}
        loader={loader}
        label={t`Centrer la carte en recherchant une adresse`}
        ariaLabelledbyPrefix={ariaLabelledbyPrefix}
        description={t`Saisissez une adresse, une voie, un lieu-dit ou une commune. Exemple : 11 rue Réaumur, Paris`}
        placeholder={t`Commencez à saisir`}
        onChange={(item) => {
          const feature = item?.data as Feature | undefined;
          if (map && feature?.geometry) {
            fitGeometry(map, feature.geometry);
          }
        }}
      />
    </div>
  );
}
