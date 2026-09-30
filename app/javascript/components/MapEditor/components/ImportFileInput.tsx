import {
  useState,
  useCallback,
  type MouseEvent,
  type ChangeEvent
} from 'react';
import type { FeatureCollection } from 'geojson';
import invariant from 'tiny-invariant';

import { readGeoFile } from '../../Map/readGeoFile';
import { generateId } from '../../shared/maplibre/utils';
import type { CreateFeatures, DeleteFeatures } from '../hooks';

export function ImportFileInput({
  featureCollection,
  createFeatures,
  deleteFeatures,
  translations
}: {
  featureCollection: FeatureCollection;
  createFeatures: CreateFeatures;
  deleteFeatures: DeleteFeatures;
  translations: Record<string, string>;
}) {
  const { inputs, addInputFile, removeInputFile, onFileChange } =
    useImportFiles(featureCollection, { createFeatures, deleteFeatures });

  return (
    <div className="file-import fr-mb-3w">
      <button
        className="fr-btn fr-btn--secondary fr-btn--icon-left fr-icon-add-circle-line"
        onClick={addInputFile}
      >
        {translations.add_file}
      </button>
      <div>
        {inputs.map((input) => (
          <div key={input.id}>
            <input
              title={translations.choose_file}
              className="fr-mt-2w"
              id={input.id}
              type="file"
              accept=".gpx, .kml"
              disabled={input.disabled}
              onChange={(e) => onFileChange(e, input.id)}
            />
            {input.hasValue && (
              <span
                title={translations.delete_file}
                className="fr-icon-delete-line fr-text-default--error"
                style={{
                  cursor: 'pointer'
                }}
                onClick={(e) => removeInputFile(e, input.id)}
              ></span>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

type FileInput = {
  id: string;
  disabled: boolean;
  hasValue: boolean;
  filename: string;
};

function useImportFiles(
  featureCollection: FeatureCollection,
  {
    createFeatures,
    deleteFeatures
  }: { createFeatures: CreateFeatures; deleteFeatures: DeleteFeatures }
) {
  const [inputs, setInputs] = useState<FileInput[]>([]);
  const addInput = useCallback(
    (input: FileInput) => {
      setInputs((inputs) => [...inputs, input]);
    },
    [setInputs]
  );
  const removeInput = useCallback(
    (inputId: string) => {
      setInputs((inputs) => inputs.filter((input) => input.id !== inputId));
    },
    [setInputs]
  );

  const onFileChange = useCallback(
    async (event: ChangeEvent<HTMLInputElement>, inputId: string) => {
      invariant(event.target.files, '');
      const { features, filename } = await readGeoFile(event.target.files[0]);
      createFeatures({ features, external: true });
      setInputs((inputs) => {
        return inputs.map((input) => {
          if (input.id === inputId) {
            return { ...input, disabled: true, hasValue: true, filename };
          }
          return input;
        });
      });
    },
    [setInputs, createFeatures]
  );

  const addInputFile = useCallback(
    (event: MouseEvent) => {
      event.preventDefault();
      addInput({
        id: generateId(),
        disabled: false,
        hasValue: false,
        filename: ''
      });
    },
    [addInput]
  );

  const removeInputFile = useCallback(
    (event: MouseEvent, inputId: string) => {
      event.preventDefault();
      const filename = inputs.find((input) => input.id === inputId)?.filename;
      const features = featureCollection.features.filter(
        (feature) => feature.properties?.filename == filename
      );
      deleteFeatures({ features, external: true });
      removeInput(inputId);
    },
    [inputs, removeInput, deleteFeatures, featureCollection]
  );

  return {
    inputs,
    onFileChange,
    addInputFile,
    removeInputFile
  };
}
