import { useLingui } from '@lingui/react/macro';

import { useFeature, useFeatureActions } from './FeatureCollectionProvider';

// Removes a geo area from the list under the map of the editor.
export function RemoveFeatureButton({
  id,
  label
}: {
  id: string;
  label: string;
}) {
  const { t } = useLingui();
  const feature = useFeature(id);
  const actions = useFeatureActions();

  if (!feature || !actions) {
    return null;
  }

  return (
    <button
      type="button"
      className="fr-btn fr-btn--tertiary-no-outline fr-btn--sm fr-btn--icon-left fr-icon-delete-line fr-mt-1w"
      onClick={() => {
        if (window.confirm(t`Supprimer « ${label} » ?`)) {
          actions.remove([id]);
        }
      }}
    >
      {t`Supprimer`} <span className="fr-sr-only">{label}</span>
    </button>
  );
}
