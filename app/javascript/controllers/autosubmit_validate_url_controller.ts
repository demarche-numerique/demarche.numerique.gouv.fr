import { ApplicationController } from './application_controller';
import { httpRequest } from '../shared/utils';

export class AutosubmitValidateUrlController extends ApplicationController {
  static values = { url: String };

  declare urlValue: string;

  #timeout?: ReturnType<typeof setTimeout>;

  debounce() {
    if (this.#timeout) clearTimeout(this.#timeout);
    this.#timeout = setTimeout(() => this.#submit(), 500);
  }

  disconnect() {
    if (this.#timeout) clearTimeout(this.#timeout);
  }

  #submit() {
    const form = this.element.closest('form');
    if (!form || !this.urlValue) return;

    const formData = new FormData(form);
    httpRequest(this.urlValue, { method: 'POST', body: formData }).turbo();
  }
}
