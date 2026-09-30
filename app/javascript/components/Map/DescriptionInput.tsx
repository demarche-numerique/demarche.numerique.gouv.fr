import { useId } from 'react';
import { useLingui } from '@lingui/react/macro';

import { useFeature, useFeatureActions } from './FeatureCollectionProvider';

// The description of a geo area, in the list under the map of the editor.
export function DescriptionInput({ id, label }: { id: string; label: string }) {
  const { t } = useLingui();
  const inputId = useId();
  const feature = useFeature(id);
  const actions = useFeatureActions();

  if (!feature || !actions) {
    return null;
  }

  return (
    // The description is saved with the collection, not as an input of its own.
    <div className="fr-input-group width-100 fr-mt-1w" data-autosave-ignore>
      <label className="fr-label" htmlFor={inputId}>
        {t`Description`} <span className="fr-sr-only">({label})</span>
      </label>
      <input
        id={inputId}
        className="fr-input"
        value={feature.properties?.description ?? ''}
        onChange={(event) =>
          actions.update(id, {
            properties: { description: event.target.value }
          })
        }
      />
    </div>
  );
}
