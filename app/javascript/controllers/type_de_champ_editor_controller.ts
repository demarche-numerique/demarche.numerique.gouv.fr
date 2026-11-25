import type { ActionEvent } from '@hotwired/stimulus';
import { getConfig, httpRequest } from '@utils';
import { matchInputElement } from 'coldwired/utils';

import { AutoUpload } from '../shared/activestorage/auto-upload';
import { ApplicationController } from './application_controller';

const {
  autosave: { debounce_delay }
} = getConfig();

const AUTOSAVE_DEBOUNCE_DELAY = debounce_delay;

export class TypeDeChampEditorController extends ApplicationController {
  declare readonly isVisible: boolean;

  #latestPromise = Promise.resolve();
  #dirtyForms: Set<HTMLFormElement> = new Set();
  #queuedForms: Map<HTMLFormElement, AbortController> = new Map();
  #inFlightForms: Map<HTMLFormElement, AbortController> = new Map();

  connect() {
    this.#latestPromise = Promise.resolve();
    this.on('change', (event) => this.onChange(event));
    this.on('input', (event) => this.onInput(event));
  }

  disconnect() {
    super.disconnect();
    this.#latestPromise = Promise.resolve();
    for (const controller of this.#queuedForms.values()) {
      controller.abort();
    }
    this.#queuedForms.clear();
    for (const controller of this.#inFlightForms.values()) {
      controller.abort();
    }
    this.#inFlightForms.clear();
  }

  // a move of the type de champ: the button names the endpoint
  onEditButtonClick(event: ActionEvent) {
    const form = createForm(event.params.url, 'patch');
    this.requestSubmitForm(form);
  }

  private onChange(event: Event) {
    matchInputElement(event.target, {
      file: (target) => {
        if (target.files?.length && target.name != 'referentiel_file') {
          const autoupload = new AutoUpload(target, target.files[0]);
          // The error is already displayed above the input by `AutoUpload`;
          // swallow the rejection so it is not reported as unhandled.
          autoupload.start().catch(() => null);
        }
        if (target.files?.length && target.name == 'referentiel_file') {
          this.requestSubmitForm(target.form);
        }
      },
      changeable: (target) => this.save(target.form),
      // dossier link combobox use hidden input to trigger saves
      hidden: (target) => this.save(target.form)
    });
  }

  private onInput(event: Event) {
    matchInputElement(event.target, {
      inputable: (target) => {
        if (target.form) {
          this.#dirtyForms.add(target.form);
          this.debounce(this.save, AUTOSAVE_DEBOUNCE_DELAY);
        }
      }
    });
  }

  private save(form?: HTMLFormElement | null): void {
    if (form) {
      createHiddenInput(form, 'should_render', true);
    } else {
      this.element.querySelector('input[name="should_render"]')?.remove();
    }

    this.requestSubmitForm(form);
  }

  private requestSubmitForm(form?: HTMLFormElement | null) {
    if (form) {
      this.submitForm(form);
    } else {
      const forms = [...this.#dirtyForms];
      this.#dirtyForms.clear();

      for (const form of forms) {
        this.submitForm(form);
      }
    }
  }

  private submitForm(form: HTMLFormElement) {
    // Saves are serialized through `#latestPromise` and each request reads the
    // form's values (`FormData` below) only when it starts. A save already
    // queued for this form will therefore pick up this latest change — nothing
    // to enqueue. And we never abort an in-flight request to supersede it:
    // aborting only cancels it client-side — the server still processes it —
    // so dispatching the next save early would let two updates race
    // server-side, where the stale one can commit last.
    if (this.#queuedForms.has(form)) {
      return;
    }

    const controller = new AbortController();
    this.#queuedForms.set(form, controller);

    this.#latestPromise = this.#latestPromise.finally(() => {
      this.#queuedForms.delete(form);
      if (controller.signal.aborted) {
        return;
      }
      this.#inFlightForms.set(form, controller);

      return httpRequest(form.action, {
        method: form.getAttribute('method') ?? '',
        body: new FormData(form),
        signal: controller.signal
      })
        .turbo()
        .catch(() => null)
        .finally(() => {
          if (this.#inFlightForms.get(form) == controller) {
            this.#inFlightForms.delete(form);
          }
        });
    });
  }
}

function createForm(action: string, method: string) {
  const form = document.createElement('form');
  form.action = action;
  form.method = 'post';
  createHiddenInput(form, '_method', method);
  return form;
}

function createHiddenInput(
  form: HTMLFormElement,
  name: string,
  value: unknown
) {
  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = name;
  input.value = String(value);
  form.appendChild(input);
}
