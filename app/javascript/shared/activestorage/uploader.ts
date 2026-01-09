import { DirectUpload } from '@rails/activestorage';
import { httpRequest, ResponseError } from '@utils';
import {
  ERROR_CODE_ATTACH,
  errorFromDirectUploadMessage,
  FileUploadError
} from './file-upload-error';
import ProgressBar from './progress-bar';

const BYTES_TO_MB_RATIO = 1_048_576;
/**
  Uploader class is a delegate for DirectUpload instance
  used to track lifecycle and progress of an upload.
  */
export default class Uploader {
  directUpload: DirectUpload;
  progressBar: ProgressBar;
  autoAttachUrl?: string;
  maxFileSize: number;
  file: File;

  constructor(
    input: HTMLInputElement,
    file: File,
    directUploadUrl: string,
    autoAttachUrl?: string,
    maxFileSize?: string
  ) {
    this.file = file;
    this.directUpload = new DirectUpload(file, directUploadUrl, this);
    this.progressBar = new ProgressBar(input, this.directUpload.id + '', file);
    this.autoAttachUrl = autoAttachUrl;
    try {
      this.maxFileSize = parseInt(maxFileSize || '0', 10);
    } catch {
      this.maxFileSize = 0;
    }
  }

  /**
    Upload (and optionally attach) the file.
    Returns the blob signed id on success.
    Throws a FileUploadError on failure.
    */
  async start() {
    this.progressBar.start();
    if (this.maxFileSize > 0 && this.file.size > this.maxFileSize) {
      throw `La taille du fichier ne peut dépasser
             ${this.maxFileSize / BYTES_TO_MB_RATIO} Mo
             (in english: File size can't be bigger than
             ${this.maxFileSize / BYTES_TO_MB_RATIO} Mo).`;
    }
    try {
      const blobSignedId = await this.upload();

      if (this.autoAttachUrl) {
        await this.attach(blobSignedId, this.autoAttachUrl);
        // On response, the attachment HTML fragment will replace the progress bar.
      } else {
        this.progressBar.end();
        this.progressBar.destroy();
      }

      return blobSignedId;
    } catch (error) {
      this.progressBar.error((error as Error).message);
      throw error;
    }
  }

  /**
    Upload the file using the DirectUpload instance, and return the blob signed_id.
    Throws a FileUploadError on failure.
    */
  private async upload(): Promise<string> {
    return new Promise((resolve, reject) => {
      this.directUpload.create((errorMsg, attributes) => {
        if (errorMsg) {
          const error = errorFromDirectUploadMessage(errorMsg);
          reject(error);
        } else {
          resolve(attributes.signed_id);
        }
      });
    });
  }

  /**
    Attach the file by sending a POST request to the autoAttachUrl.
    Throws a FileUploadError on failure (containing the first validation
    error message, if any).
    */
  private async attach(blobSignedId: string, autoAttachUrl: string) {
    const formData = new FormData();
    formData.append('blob_signed_id', blobSignedId);

    try {
      await httpRequest(autoAttachUrl, {
        method: 'post',
        body: formData,
        headers: { 'x-http-method-override': 'PUT' }
      }).turbo();
    } catch (e) {
      const error = e as ResponseError;
      const errors = error?.errors;
      const message = errors && errors[0];
      throw new FileUploadError(
        message ||
          `Impossible d’associer le fichier (in english: error attaching file).'`,
        error.response?.status,
        ERROR_CODE_ATTACH
      );
    }
  }

  uploadRequestDidProgress(event: ProgressEvent) {
    const progress = (event.loaded / event.total) * 100;
    if (progress) {
      this.progressBar.progress(progress);
    }
  }

  directUploadWillStoreFileWithXHR(xhr: XMLHttpRequest) {
    xhr.upload.addEventListener('progress', (event) =>
      this.uploadRequestDidProgress(event)
    );
  }
}
