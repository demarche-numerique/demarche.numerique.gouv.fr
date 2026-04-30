import invariant from 'tiny-invariant';

import Uploader from './uploader';
import {
  FileUploadError,
  ERROR_CODE_READ,
  FAILURE_CONNECTIVITY
} from './file-upload-error';

type ErrorMessage = {
  title: string;
  retry: boolean;
};

// Given a file input in a champ with a selected file, upload a file,
// then attach it to the dossier.
//
// On success, the champ is replaced by an HTML fragment describing the attachment.
// On error, a error message is displayed above the input.
export class AutoUpload {
  #input: HTMLInputElement;
  #uploader: Uploader;

  constructor(input: HTMLInputElement, file: File) {
    const { directUploadUrl, autoAttachUrl, maxFileSize } = input.dataset;
    invariant(directUploadUrl, 'Could not find the direct upload URL.');
    this.#input = input;
    this.#uploader = new Uploader(
      input,
      file,
      directUploadUrl,
      autoAttachUrl,
      maxFileSize
    );
  }

  // Create, upload and attach the file.
  // On failure, display an error message and throw a FileUploadError.
  async start() {
    try {
      this.begin();
      await this.#uploader.start();
      this.succeeded();
    } catch (error) {
      this.failed(error as FileUploadError);
      throw error;
    } finally {
      this.done();
    }
  }

  private begin() {
    this.#input.disabled = true;
  }

  private succeeded() {
    this.#input.value = '';
  }

  private failed(error: FileUploadError) {
    if (!document.body.contains(this.#input)) {
      return;
    }

    const message = this.messageFromError(error);

    // Display error in the progress bar instead of destroying it
    this.#uploader.progressBar.error(message.title);

    // Add retry button listener if retry is allowed
    if (message.retry) {
      this.attachRetryListener();
    }

    this.#input.classList.toggle('fr-text-default--error', true);
  }

  private done() {
    this.#input.disabled = false;
  }

  private messageFromError(error: FileUploadError): ErrorMessage {
    const message = error.message || error.toString();
    const canRetry = error.status && error.status != 422;

    if (error.failureReason == FAILURE_CONNECTIVITY) {
      return {
        title:
          'Le fichier n’a pas pu être envoyé. Vérifiez votre connexion à Internet, puis ré-essayez. Vérifiez aussi que le pare-feu de votre appareil ou votre réseau autorise l’envoi de fichier vers ' +
          window.location.host +
          ' et static.demarche.numerique.gouv.fr.',
        retry: true
      };
    } else if (error.code == ERROR_CODE_READ) {
      return {
        title:
          'Nous n’arrivons pas à lire ce fichier sur votre appareil. Essayez à nouveau, ou sélectionnez un autre fichier.',
        retry: false
      };
    } else {
      return {
        title: message,
        retry: !!canRetry
      };
    }
  }

  private attachRetryListener() {
    const progressBarElement = document.querySelector<HTMLElement>(
      `#direct-upload-${this.#uploader.directUpload.id}`
    );
    const retryButton = progressBarElement?.querySelector<HTMLButtonElement>(
      '.direct-upload__retry'
    );

    if (retryButton) {
      retryButton.classList.remove('hidden');
      retryButton.addEventListener(
        'click',
        () => {
          // Remove the error state
          progressBarElement?.classList.remove('direct-upload--error');
          const errorZone = progressBarElement?.querySelector<HTMLElement>(
            '.direct-upload__error'
          );
          errorZone?.classList.add('hidden');

          // Restart the upload
          this.start();
        },
        { once: true }
      );
    }
  }
}
