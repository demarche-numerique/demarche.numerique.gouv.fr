import invariant from 'tiny-invariant';

const PENDING_CLASS = 'direct-upload--pending';
const ERROR_CLASS = 'direct-upload--error';
const COMPLETE_CLASS = 'direct-upload--complete';

/**
  ProgressBar is and utility class responsible for
  rendering upload progress bar. It is used to handle
  direct-upload form ujs events but also in the
  Uploader delegate used with uploads on json api.

  As the associated DOM element may disappear for some
  reason (a dynamic React list, an element being removed
  and recreated again later, etc.), this class doesn't
  raise any error if the associated DOM element cannot
  be found.
  */
export default class ProgressBar {
  static init(input: HTMLInputElement, id: string, file: File) {
    clearErrors(input);
    const html = this.render(id, file.name);
    input.before(html);
  }

  static start(id: string) {
    const element = getDirectUploadElement(id);
    if (element) {
      element.classList.remove(PENDING_CLASS);
      element.focus();
    }
  }

  static progress(id: string, progress: number) {
    const element = getDirectUploadProgressElement(id);
    if (element) {
      element.style.width = `${progress}%`;
      element.setAttribute('aria-valuenow', `${progress}`);
    }
  }

  static error(id: string, error: string) {
    const element = getDirectUploadElement(id);
    if (element) {
      element.classList.add(ERROR_CLASS);
      element.classList.add('fr-fieldset--error');
      element.setAttribute('title', error);

      // Display error message in the error zone
      const errorMessage = element.querySelector<HTMLElement>(
        '.direct-upload__error-message'
      );
      if (errorMessage) {
        errorMessage.textContent = error;
      }
      const retryButton = element.querySelector<HTMLButtonElement>(
        '.direct-upload__retry'
      );
      if (retryButton) {
        retryButton.classList.remove('hidden');
      }

      // Show the error zone
      const errorZone = element.querySelector<HTMLElement>(
        '.direct-upload__error'
      );
      if (errorZone) {
        errorZone.classList.remove('hidden');
      }
    }
  }

  static end(id: string) {
    const element = getDirectUploadElement(id);
    if (element) {
      element.classList.add(COMPLETE_CLASS);
    }
  }

  static render(id: string, filename: string) {
    const template = document.querySelector<HTMLTemplateElement>(
      '#progress-bar-template'
    );
    invariant(template, 'Missing progress-bar-template');
    const fragment = template.content.cloneNode(true) as DocumentFragment;
    const container = fragment.querySelector<HTMLDivElement>('.direct-upload');
    invariant(container, 'Missing .direct-upload element in template');
    const slot = container.querySelector<HTMLSlotElement>(
      'slot[name="filename"]'
    );
    invariant(slot, 'Missing "filename" slot in template');

    container.id = `direct-upload-${id}`;
    container.dataset.directUploadId = id;
    container.classList.add(PENDING_CLASS);
    slot.replaceWith(document.createTextNode(filename));

    return container;
  }

  id: string;

  constructor(input: HTMLInputElement, id: string, file: File) {
    ProgressBar.init(input, id, file);
    this.id = id;
  }

  start() {
    ProgressBar.start(this.id);
  }

  progress(progress: number) {
    ProgressBar.progress(this.id, progress);
  }

  error(error: string) {
    ProgressBar.error(this.id, error);
  }

  end() {
    ProgressBar.end(this.id);
  }

  destroy() {
    const element = getDirectUploadElement(this.id);
    element?.remove();
  }
}

function clearErrors(input: HTMLInputElement) {
  const errorElements =
    input.parentElement?.querySelectorAll(`.${ERROR_CLASS}`) ?? [];
  for (const element of errorElements) {
    element.remove();
  }
}

function getDirectUploadElement(id: string) {
  return document.querySelector<HTMLDivElement>(`#direct-upload-${id}`);
}

function getDirectUploadProgressElement(id: string) {
  return document.querySelector<HTMLDivElement>(
    `#direct-upload-${id} .direct-upload__progress`
  );
}
