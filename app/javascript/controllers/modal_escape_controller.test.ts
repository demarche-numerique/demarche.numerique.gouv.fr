import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test, vi } from 'vitest';

import { ModalEscapeController } from './modal_escape_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

suite('ModalEscapeController', () => {
  let application: Application;
  const modal = { conceal: vi.fn(), focus: vi.fn() };

  beforeEach(async () => {
    (window as unknown as { dsfr: unknown }).dsfr = vi.fn(() => ({ modal }));
    document.body.innerHTML = `
      <dialog id="modal" data-controller="modal-escape">
        <input type="checkbox" data-action="keydown.esc->modal-escape#close">
      </dialog>
    `;
    application = Application.start();
    application.register('modal-escape', ModalEscapeController);
    await nextFrame();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.restoreAllMocks();
  });

  test('conceals the DSFR modal and gives focus back to its trigger', () => {
    const input = document.querySelector('input') as HTMLInputElement;

    input.dispatchEvent(
      new KeyboardEvent('keydown', { key: 'Escape', bubbles: true })
    );

    expect(modal.conceal).toHaveBeenCalledOnce();
    expect(modal.focus).toHaveBeenCalledOnce();
  });
});
