import { isButtonElement, matchInputElement } from '@coldwired/utils';
import { getConfig, httpRequest, ResponseError } from '@utils';

import { AutoUpload } from '../shared/activestorage/auto-upload';
import {
  ERROR_CODE_READ,
  FAILURE_CLIENT,
  FileUploadError
} from '../shared/activestorage/file-upload-error';
import {
  showAttachmentError,
  hideAttachmentError
} from '../shared/attachment-error';
import { ApplicationController } from './application_controller';

/**
 * Erreur de validation pour un fichier
 */
interface FileValidationError {
  file: File;
  errors: string[];
}

const {
  autosave: { debounce_delay }
} = getConfig();

const AUTOSAVE_DEBOUNCE_DELAY = debounce_delay;
const AUTOSAVE_TIMEOUT_DELAY = 60000;
const AUTOSAVE_CONDITIONAL_SPINNER_DEBOUNCE_DELAY = 200;

// This is a controller we attach to each "champ" in the main form. It performs
// the save and dispatches a few events that allow `AutosaveStatusController` to
// coordinate notifications and retries:
// * `autosave:enqueue` - dispatched when a new save attempt starts
// * `autosave:end` - dispatched after sucessful save
// * `autosave:error` - dispatched when an error occures
//
// The controller also listens to the following events:
// * `autosave:retry` - dispatched by `AutosaveStatusController` when the user
// clicks the retry button in the form status bar
//
export class AutosaveController extends ApplicationController {
  #abortController?: AbortController;
  #latestPromise = Promise.resolve();
  #needsRetry = false;
  #pendingPromiseCount = 0;
  #spinnerTimeoutId?: ReturnType<typeof setTimeout>;

  connect() {
    this.#latestPromise = Promise.resolve();
    this.onGlobal('autosave:retry', () => this.didRequestRetry());
    this.on('change', (event) => this.onChange(event));
    this.on('input', (event) => this.onInput(event));
  }

  disconnect() {
    this.#abortController?.abort();
    this.#latestPromise = Promise.resolve();
  }

  onClickRetryButton(event: Event) {
    const target = event.target;
    if (isButtonElement(target)) {
      const inputTargetSelector = target.dataset.inputTarget;
      if (inputTargetSelector) {
        const target =
          this.element.querySelector<HTMLInputElement>(inputTargetSelector);
        if (
          target &&
          target.type == 'file' &&
          target.dataset.autoAttachUrl &&
          target.files?.length
        ) {
          this.enqueueAutouploadRequest(target, target.files[0]);
        }
      }
    }
  }

  private onChange(event: Event) {
    matchInputElement(event.target, {
      file: (target) => {
        if (target.dataset.autoAttachUrl && target.files?.length) {
          // IMPORTANT : Masquer et nettoyer les erreurs précédentes avant tout traitement
          hideAttachmentError(target);

          this.globalDispatch('autosave:input');

          const allFiles = Array.from(target.files);

          // Partitionner les fichiers en valides et invalides
          const { validFiles, invalidFiles } = this.partitionFiles(
            target,
            allFiles
          );

          // Afficher toutes les erreurs en une seule fois
          if (invalidFiles.length > 0) {
            this.showFileErrors(target, invalidFiles);
          }

          // Upload uniquement les fichiers valides
          for (const file of validFiles) {
            this.enqueueAutouploadRequest(target, file);
          }
        }
      },
      changeable: (target) => {
        this.globalDispatch('autosave:input');

        // Wait next tick so champs having JS can interact
        // with form elements before extracting form data.
        setTimeout(() => {
          this.enqueueAutosaveWithValidationRequest();
          this.showConditionnalSpinner(target);
        }, 0);
      },
      inputable: () => {
        // we already save on input for inputable elements
      },
      hidden: (target) => {
        // In comboboxes we dispatch a "change" event on hidden inputs to trigger autosave.
        // We want to debounce them.
        this.enqueueOnInput(target);
      }
    });
  }

  private onInput(event: Event) {
    matchInputElement(event.target, {
      inputable: (target) => {
        // Ignore input from React comboboxes. We trigger "change" events on them when selection is changed.
        if (target.getAttribute('role') != 'combobox') {
          this.enqueueOnInput(target);
        }
      }
    });
  }

  private enqueueOnInput(target: HTMLInputElement | HTMLTextAreaElement) {
    this.globalDispatch('autosave:input');

    this.debounce(
      this.enqueueAutosaveWithValidationRequest,
      AUTOSAVE_DEBOUNCE_DELAY
    );

    this.showConditionnalSpinner(target);
  }

  private showConditionnalSpinner(
    target: HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement
  ) {
    const champWrapperElement = target.closest(
      '.editable-champ[data-dependent-conditions]'
    );

    if (!champWrapperElement) {
      return;
    }

    this.showSpinner(champWrapperElement);
  }

  private showSpinner(champElement: Element) {
    this.#spinnerTimeoutId = setTimeout(() => {
      // do not do anything if there is already a spinner for this champ, like SIRET champ
      if (!champElement.nextElementSibling?.classList.contains('spinner')) {
        const spinner = document.createElement('div');
        spinner.classList.add('spinner', 'spinner-removable');
        spinner.setAttribute('aria-live', 'live');
        spinner.setAttribute('aria-label', 'Chargement en cours…');
        champElement.insertAdjacentElement('afterend', spinner);
      }
    }, AUTOSAVE_CONDITIONAL_SPINNER_DEBOUNCE_DELAY);
  }

  private didRequestRetry() {
    if (this.#needsRetry) {
      this.enqueueAutosaveWithValidationRequest();
    }
  }

  private didEnqueue() {
    this.#needsRetry = false;
    this.globalDispatch('autosave:enqueue');
  }

  private didSucceed() {
    this.#pendingPromiseCount -= 1;
    if (this.#pendingPromiseCount == 0) {
      this.globalDispatch('autosave:end');
      clearTimeout(this.#spinnerTimeoutId);
    }
  }

  private didFail(error: ResponseError) {
    this.#needsRetry = true;
    this.#pendingPromiseCount -= 1;
    this.globalDispatch('autosave:error', { error });
  }

  private enqueueAutouploadRequest(target: HTMLInputElement, file: File) {
    const autoupload = new AutoUpload(target, file);
    autoupload
      .start()
      .catch((e) => {
        const error = e as FileUploadError;

        this.globalDispatch('autosave:error', { error });

        // Report unexpected client errors to Sentry.
        // (But ignore usual client errors, or errors we can monitor better on the server side.)
        if (
          error.failureReason == FAILURE_CLIENT &&
          error.code != ERROR_CODE_READ
        ) {
          throw error;
        }
      })
      .then(() => {
        this.globalDispatch('autosave:end');
      });
  }

  private enqueueAutosaveWithValidationRequest() {
    this.#latestPromise = this.#latestPromise.finally(() =>
      this.sendAutosaveRequest(true)
        .then(() => this.didSucceed())
        .catch((error) => this.didFail(error))
    );
    this.didEnqueue();
  }

  // Create a fetch request that saves the form.
  // Returns a promise fulfilled when the request completes.
  private sendAutosaveRequest(validate = false): Promise<void> {
    this.#abortController = new AbortController();
    const { form, inputs } = this;

    if (!form || inputs.length == 0) {
      return Promise.resolve();
    }

    const formData = new FormData();
    for (const input of inputs) {
      if (input.type == 'checkbox') {
        formData.append(input.name, input.checked ? input.value : '');
      } else if (input.type == 'radio') {
        if (input.checked) {
          formData.append(input.name, input.value);
        }
      } else {
        // NOTE: some type inputs (like number) have an empty input.value
        // when the filled value is invalid (not a number) so we avoid them
        formData.append(input.name, input.value);
      }
    }
    if (validate) {
      formData.append('validate', 'true');
    }

    this.#pendingPromiseCount++;

    return httpRequest(form.action, {
      method: 'post',
      body: formData,
      headers: {
        'x-http-method-override':
          form.dataset.turboMethod?.toUpperCase() || 'PATCH'
      },
      signal: this.#abortController.signal,
      timeout: AUTOSAVE_TIMEOUT_DELAY
    }).turbo();
  }

  private get form() {
    return this.element.closest('form');
  }

  private get inputs() {
    const element = this.element as HTMLElement;

    return [
      ...element.querySelectorAll<HTMLInputElement>(
        'input:not([type=file]), textarea, select'
      )
    ].filter((element) => !element.disabled);
  }

  private partitionFiles(
    input: HTMLInputElement,
    files: File[]
  ): { validFiles: File[]; invalidFiles: FileValidationError[] } {
    const validFiles: File[] = [];
    const invalidFiles: FileValidationError[] = [];
    const maxFilesRemaining = this.getMaxFilesRemaining(input);

    for (let index = 0; index < files.length; index++) {
      const file = files[index];
      const errors: string[] = [];

      const limitError = this.checkFileLimit(input, index, maxFilesRemaining);
      if (limitError) {
        errors.push(limitError);
      }

      const formatError = this.checkFileFormat(input, file);
      if (formatError) {
        errors.push(formatError);
      }

      const sizeError = this.checkFileSize(input, file);
      if (sizeError) {
        errors.push(sizeError);
      }

      if (errors.length > 0) {
        invalidFiles.push({ file, errors });
      } else {
        validFiles.push(file);
      }
    }

    return { validFiles, invalidFiles };
  }

  private showFileErrors(
    input: HTMLInputElement,
    invalidFiles: FileValidationError[]
  ): void {
    const uniqueErrors = [
      ...new Set(invalidFiles.flatMap(({ errors }) => errors))
    ];

    showAttachmentError(input, uniqueErrors);
  }

  /**
   * Parse l'attribut accept pour générer un label lisible
   * Extrait les extensions et catégories MIME directement depuis accept
   * @example ".pdf,.docx,image/*" → "PDF, DOCX, images"
   */
  private parseAcceptForDisplay(accept: string): string {
    const acceptedFormats = accept
      .split(',')
      .map((format) => format.trim().toLowerCase());

    const displayItems: string[] = [];

    for (const format of acceptedFormats) {
      if (format.startsWith('.')) {
        const ext = format.substring(1).toUpperCase();
        if (!displayItems.includes(ext)) {
          displayItems.push(ext);
        }
      } else if (format.includes('/*')) {
        const category = format.split('/')[0];
        const label = this.getFormatFamilyLabel(category);
        if (!displayItems.includes(label)) {
          displayItems.push(label);
        }
      } else {
        const label = this.getMimeTypeLabel(format);
        if (label && !displayItems.includes(label)) {
          displayItems.push(label);
        }
      }
    }

    // Si aucune extension/wildcard/MIME type reconnu, message générique
    if (displayItems.length === 0) {
      return 'certains formats spécifiques';
    }

    return displayItems.join(', ');
  }

  /**
   * Retourne le label correspondant à une famille de formats
   * Basé sur FORMAT_FAMILY_EXAMPLES de config/initializers/authorized_content_types.rb
   */
  private getFormatFamilyLabel(mimeCategory: string): string {
    const formatFamilyLabels: Record<string, string> = {
      // Correspond à FORMAT_FAMILY_EXAMPLES[:image_scan]
      image: '.jpg, .jpeg, .png',
      // Correspond à FORMAT_FAMILY_EXAMPLES[:video]
      video: '.mp4, .mov, .avi, .wmv',
      // Correspond à FORMAT_FAMILY_EXAMPLES[:audio]
      audio: '.mp3, .wav, .aac, .m4a',
      // Correspond à FORMAT_FAMILY_EXAMPLES[:document_texte] (partiel)
      application: '.pdf, .doc, .docx, .odt, .txt',
      // Correspond à FORMAT_FAMILY_EXAMPLES[:donnees] (partiel)
      text: '.xml, .json, .txt, .csv'
    };

    return formatFamilyLabels[mimeCategory] || mimeCategory;
  }

  /**
   * Convertit un MIME type exact vers son label correspondant de FORMAT_FAMILY_EXAMPLES
   * Mapping basé sur FORMAT_FAMILIES (config/initializers/authorized_content_types.rb)
   */
  private getMimeTypeLabel(mimeType: string): string | null {
    // Mapping des MIME types utilisés dans FORMAT_FAMILIES vers leurs labels
    const mimeToFamilyLabel: Record<string, string> = {
      // image_scan → '.jpg, .jpeg, .png'
      'image/jpeg': '.jpg, .jpeg, .png',
      'image/png': '.jpg, .jpeg, .png',

      // document_texte → '.pdf, .doc, .docx, .odt, .txt'
      'application/pdf': '.pdf, .doc, .docx, .odt, .txt',
      'application/x-pdf': '.pdf, .doc, .docx, .odt, .txt',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        '.pdf, .doc, .docx, .odt, .txt',
      'application/vnd.oasis.opendocument.text':
        '.pdf, .doc, .docx, .odt, .txt',
      'application/msword': '.pdf, .doc, .docx, .odt, .txt',
      'text/plain': '.pdf, .doc, .docx, .odt, .txt',

      // tableur → '.xls, .xlsx, .ods, .csv'
      'application/vnd.ms-excel': '.xls, .xlsx, .ods, .csv',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        '.xls, .xlsx, .ods, .csv',
      'application/vnd.oasis.opendocument.spreadsheet':
        '.xls, .xlsx, .ods, .csv',
      'text/csv': '.xls, .xlsx, .ods, .csv',

      // presentation → '.ppt, .pptx, .odp'
      'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        '.ppt, .pptx, .odp',
      'application/vnd.ms-powerpoint': '.ppt, .pptx, .odp',

      // audio → '.mp3, .wav, .aac, .m4a'
      'audio/mpeg': '.mp3, .wav, .aac, .m4a',
      'audio/mp4': '.mp3, .wav, .aac, .m4a',
      'audio/x-m4a': '.mp3, .wav, .aac, .m4a',
      'audio/aac': '.mp3, .wav, .aac, .m4a',
      'audio/x-wav': '.mp3, .wav, .aac, .m4a',

      // video → '.mp4, .mov, .avi, .wmv'
      'video/mp4': '.mp4, .mov, .avi, .wmv',
      'video/quicktime': '.mp4, .mov, .avi, .wmv',
      'video/3gpp': '.mp4, .mov, .avi, .wmv',
      'video/x-ms-wm': '.mp4, .mov, .avi, .wmv',

      // archive → '.zip, .rar, .7z, .gz'
      'application/zip': '.zip, .rar, .7z, .gz',
      'application/x-zip-compressed': '.zip, .rar, .7z, .gz',
      'application/x-7z-compressed': '.zip, .rar, .7z, .gz',
      'application/vnd.rar': '.zip, .rar, .7z, .gz',
      'application/x-rar': '.zip, .rar, .7z, .gz',
      'application/gzip': '.zip, .rar, .7z, .gz'
    };

    return mimeToFamilyLabel[mimeType] || null;
  }

  private checkFileFormat(input: HTMLInputElement, file: File): string | null {
    const accept = input.accept;
    if (!accept) return null;

    const acceptedFormats = accept
      .split(',')
      .map((format) => format.trim().toLowerCase());

    const fileName = file.name.toLowerCase();
    const fileExtension = fileName.substring(fileName.lastIndexOf('.'));

    const isAccepted = acceptedFormats.some((format) => {
      if (format.startsWith('.')) {
        return fileExtension === format;
      } else if (format.includes('/*')) {
        const mimeType = format.split('/')[0];
        return file.type.startsWith(mimeType + '/');
      } else {
        return file.type === format;
      }
    });

    if (!isAccepted) {
      // Parser accept directement pour construire le message d'erreur
      const formatsLabel = this.parseAcceptForDisplay(accept);
      return `Les formats de fichier acceptés sont :&nbsp;<strong>${formatsLabel}</strong>.`;
    }

    return null;
  }

  private checkFileSize(input: HTMLInputElement, file: File): string | null {
    const maxSize = input.dataset.maxFileSize
      ? parseInt(input.dataset.maxFileSize, 10)
      : 0;

    if (!maxSize) return null; // Pas de limite

    if (file.size > maxSize) {
      const maxSizeMB = (maxSize / (1024 * 1024)).toFixed(0);
      return `La taille maximale du fichier autorisée est de&nbsp;<strong>${maxSizeMB} Mo</strong>.`;
    }

    return null;
  }

  private countCurrentFiles(container: Element): number {
    const persistedCount = container.querySelectorAll(
      '[data-attachment-row]'
    ).length;

    const inFlightCount = container.querySelectorAll(
      '.direct-upload:not(.direct-upload--complete):not(.direct-upload--error)'
    ).length;

    return persistedCount + inFlightCount;
  }

  /**
   * Calcule le nombre de fichiers restants qu'on peut ajouter
   * @returns Le nombre de slots disponibles, ou Infinity si pas de limite
   */
  private getMaxFilesRemaining(input: HTMLInputElement): number {
    const max = input.dataset.max ? parseInt(input.dataset.max, 10) : 0;
    if (!max) return Infinity; // Pas de limite

    const container = input.closest('.attachment-multiple');
    if (!container) return Infinity; // Pas dans un contexte multiple

    const currentCount = this.countCurrentFiles(container);
    return Math.max(0, max - currentCount);
  }

  /**
   * Vérifie si un fichier dépasse la limite de nombre
   * @param index Position du fichier dans la liste
   * @param maxRemaining Nombre maximum de fichiers qu'on peut encore ajouter
   * @returns Le message d'erreur si limite dépassée, null sinon
   */
  private checkFileLimit(
    input: HTMLInputElement,
    index: number,
    maxRemaining: number
  ): string | null {
    if (maxRemaining === Infinity) return null; // Pas de limite

    if (index >= maxRemaining) {
      const max = input.dataset.max ? parseInt(input.dataset.max, 10) : 0;
      return `Le nombre de fichiers maximum est de&nbsp;<strong> ${max}</strong>.`;
    }

    return null;
  }
}
