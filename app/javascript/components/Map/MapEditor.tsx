import { useEffect, useRef, type ReactNode } from 'react';
import type { FeatureCollection } from 'geojson';

import { MapLibreProvider } from './MapLibreProvider';
import {
  useFeatureCollection,
  useRevision,
  WritableFeatureCollectionProvider
} from './FeatureCollectionProvider';
import { serializeFeatures, type EditableFeature } from './collection';

export function MapEditor({
  featureCollection,
  name,
  rejected,
  children
}: {
  featureCollection: FeatureCollection;
  name: string;
  rejected?: string[];
  children: ReactNode;
}) {
  return (
    <MapLibreProvider>
      <WritableFeatureCollectionProvider
        featureCollection={featureCollection}
        rejected={rejected}
      >
        <ValueInput name={name} />
        {children}
      </WritableFeatureCollectionProvider>
    </MapLibreProvider>
  );
}

// The whole collection is the value of the champ: a change dispatched on this
// input saves it through the autosave of the champ, like any other champ.
function ValueInput({ name }: { name: string }) {
  const { features } = useFeatureCollection();
  const revision = useRevision();
  const ref = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (revision > 0) {
      ref.current?.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }, [revision]);

  return (
    <input
      ref={ref}
      type="hidden"
      name={name}
      value={serializeFeatures(features as EditableFeature[])}
    />
  );
}
