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
  static values = {
    typeDeChampStableId: String,
    moveUpUrl: String,
    moveDownUrl: String
  };

  declare readonly moveUpUrlValue: string;
  declare readonly moveDownUrlValue: string;
  declare readonly isVisible: boolean;

  #latestPromise = Promise.resolve();
  #dirtyForms: Set<HTMLFormElement> = new Set();
  #inFlightForms: Map<HTMLFormElement, AbortController> = new Map();

  connect() {
    this.#latestPromise = Promise.resolve();
    this.on('change', (event) => this.onChange(event));
    this.on('input', (event) => this.onInput(event));
  }

  disconnect() {
    this.#latestPromise = Promise.resolve();
    for (const [form] of this.#inFlightForms) {
      this.abortForm(form);
    }
    this.#inFlightForms.clear();
  }

  onMoveButtonClick(event: ActionEvent) {
    const { direction } = event.params;
    const action =
      direction == 'up' ? this.moveUpUrlValue : this.moveDownUrlValue;
    const form = createForm(action, 'patch');
    this.requestSubmitForm(form);
  }

  private onChange(event: Event) {
    matchInputElement(event.target, {
      file: (target) => {
        if (target.files?.length && target.name != 'referentiel_file') {
          const autoupload = new AutoUpload(target, target.files[0]);
          autoupload.start();
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
    const controller = this.abortForm(form);

    this.#latestPromise = this.#latestPromise.finally(() =>
      httpRequest(form.action, {
        method: form.getAttribute('method') ?? '',
        body: new FormData(form),
        signal: controller.signal
      })
        .turbo()
        .catch(() => null)
    );
  }

  private abortForm(form: HTMLFormElement) {
    const controller = new AbortController();
    this.#inFlightForms.get(form)?.abort();
    this.#inFlightForms.set(form, controller);
    return controller;
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
