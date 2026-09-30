import type { ReactNode } from 'react';

import { useMapLibre } from './MapLibreProvider';
import { useFeature } from './FeatureCollectionProvider';
import { fitGeometry } from './camera';

export function FeatureLink({
  id,
  children
}: {
  id: string;
  children: ReactNode;
}) {
  const map = useMapLibre();
  const feature = useFeature(id);

  if (!map || !feature) {
    return children;
  }

  return (
    <button
      type="button"
      className="fr-link"
      onClick={() => fitGeometry(map, feature.geometry)}
    >
      {children}
    </button>
  );
}
