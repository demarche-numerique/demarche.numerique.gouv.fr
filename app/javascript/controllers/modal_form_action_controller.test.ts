import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test } from 'vitest';

import { ModalFormActionController } from './modal_form_action_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

suite('ModalFormActionController', () => {
  let application: Application;

  beforeEach(async () => {
    document.body.innerHTML = `
      <button
        type="button"
        aria-controls="modal"
        data-controller="modal-form-action"
        data-action="modal-form-action#set"
        data-modal-form-action-url-param="/procedures/1/dossiers/2/archive"
      >Archive</button>
      <dialog id="modal"><form action=""><input type="checkbox" name="dismiss_archive_warning" value="1"></form></dialog>
    `;
    application = Application.start();
    application.register('modal-form-action', ModalFormActionController);
    await nextFrame();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  test('points the controlled modal form to the trigger url', () => {
    const button = document.querySelector('button') as HTMLButtonElement;
    const form = document.querySelector('form') as HTMLFormElement;

    button.click();

    expect(form.getAttribute('action')).toBe(
      '/procedures/1/dossiers/2/archive'
    );
  });

  test('forgets a previously checked choice', () => {
    const button = document.querySelector('button') as HTMLButtonElement;
    const checkbox = document.querySelector('input') as HTMLInputElement;
    checkbox.checked = true;

    button.click();

    expect(checkbox.checked).toBe(false);
  });
});
