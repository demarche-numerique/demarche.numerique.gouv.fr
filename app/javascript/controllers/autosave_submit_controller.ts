import { isButtonElement } from 'coldwired/utils';

import { ApplicationController } from './application_controller';

export class AutosaveSubmitController extends ApplicationController {
  #isSaving = false;
  #shouldSubmit = false;
  #buttonText?: string;

  connect(): void {
    this.onGlobal('autosave:input', () => this.didInput());
    this.onGlobal('autosave:end', () => this.didSucceed());
    this.onGlobal('autosave:error', () => this.didFail());
    this.on('click', (event) => this.onClick(event));

    // Guard against double submissions once this button really submits the
    // form (autosaves submit it without a submitter): a native submission
    // leaves the page, a Turbo one ends with submit-end.
    const form = isButtonElement(this.element) ? this.element.form : null;
    if (form) {
      this.on(form, 'submit', (event: SubmitEvent) => {
        if (event.submitter == this.element) {
          this.disableButton();
        }
      });
      this.on(form, 'turbo:submit-end', () => this.enableButton());
    }
  }

  // Intercept form submit if autosave is still in progress
  private onClick(event: Event) {
    if (this.#isSaving) {
      this.#shouldSubmit = true;
      this.disableButton();
      event.preventDefault();
    }
  }

  private didInput() {
    this.#isSaving = true;
    this.#shouldSubmit = false;
  }

  // If submit was previously requested, send it, now that autosave have finished
  private didSucceed() {
    if (this.#shouldSubmit && isButtonElement(this.element)) {
      this.element.form?.requestSubmit(this.element);
    }
    this.#isSaving = false;
    this.#shouldSubmit = false;
    this.enableButton();
  }

  private didFail() {
    this.#isSaving = false;
    this.#shouldSubmit = false;
    if (isButtonElement(this.element)) {
      this.element.disabled = true;
    }
  }

  private disableButton() {
    if (isButtonElement(this.element)) {
      const disableWith = this.element.dataset.disableWith ?? '';
      if (disableWith) {
        this.#buttonText = this.element.textContent ?? undefined;
        this.element.textContent = disableWith;
      }
      this.element.disabled = true;
    }
  }

  private enableButton() {
    if (isButtonElement(this.element)) {
      if (this.#buttonText) {
        this.element.textContent = this.#buttonText;
      }
      this.element.disabled = false;
    }
  }
}
