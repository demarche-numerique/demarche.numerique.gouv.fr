import { useState, type ChangeEvent } from 'react';
import { useLingui } from '@lingui/react/macro';

import { readGeoFile } from './readGeoFile';
import {
  useFeatureActions,
  useFeatureCollection
} from './FeatureCollectionProvider';

type FileInput = { id: string; filename?: string };

// Imports the shapes of GPX and KML files; removing a file removes its shapes.
export function FileImport() {
  const { t } = useLingui();
  const { features } = useFeatureCollection();
  const actions = useFeatureActions();
  const [inputs, setInputs] = useState<FileInput[]>([]);

  if (!actions) {
    return null;
  }

  const onFileChange = async (
    event: ChangeEvent<HTMLInputElement>,
    inputId: string
  ) => {
    const file = event.target.files?.[0];
    if (!file) {
      return;
    }
    const { features, filename } = await readGeoFile(file);
    actions.create(features);
    setInputs((inputs) =>
      inputs.map((input) =>
        input.id == inputId ? { ...input, filename } : input
      )
    );
  };

  const removeFile = ({ id, filename }: FileInput) => {
    actions.remove(
      features
        .filter((feature) => feature.properties?.filename == filename)
        .map((feature) => String(feature.id))
    );
    setInputs((inputs) => inputs.filter((input) => input.id != id));
  };
  const chooseFile = t`Choisir un fichier GPX ou KML`;
  const deleteFile = t`Supprimer le fichier`;

  return (
    <div className="file-import fr-mb-3w" data-autosave-ignore>
      <button
        type="button"
        className="fr-btn fr-btn--secondary fr-btn--icon-left fr-icon-add-circle-line"
        onClick={() =>
          setInputs((inputs) => [...inputs, { id: crypto.randomUUID() }])
        }
      >
        {t`Ajouter un fichier GPX ou KML`}
      </button>
      {inputs.map((input) => (
        <div key={input.id} className="flex align-center flex-gap-1 fr-mt-2w">
          <input
            title={chooseFile}
            aria-label={chooseFile}
            type="file"
            accept=".gpx, .kml"
            disabled={input.filename != null}
            onChange={(event) => onFileChange(event, input.id)}
          />
          {input.filename != null ? (
            <button
              type="button"
              className="fr-btn fr-btn--tertiary-no-outline fr-btn--sm fr-icon-delete-line"
              title={deleteFile}
              onClick={() => removeFile(input)}
            >
              {deleteFile}
            </button>
          ) : null}
        </div>
      ))}
    </div>
  );
}
