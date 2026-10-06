import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test } from 'vitest';

import { RepetitionLimitsController } from './repetition_limits_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

suite('RepetitionLimitsController', () => {
  let application: Application;
  let fieldset: HTMLFieldSetElement;

  const rows = () => fieldset.querySelector('.repetition') as HTMLElement;
  const errorMessage = () =>
    fieldset.querySelector('#bloc-error') as HTMLElement;
  const row = () =>
    '<div data-repetition-limits-target="row" class="repetition-row"></div>';

  const addRow = async () => {
    rows().insertAdjacentHTML('beforeend', row());
    await nextFrame();
  };

  const mount = async (rowsCount: number) => {
    fieldset = document.createElement('fieldset');
    fieldset.className = 'fr-fieldset fr-fieldset--error';
    fieldset.innerHTML = `
      <div data-controller="repetition-limits" data-repetition-limits-min-value="2" data-repetition-limits-error-id-value="bloc-error">
        <div class="repetition">${row().repeat(rowsCount)}</div>
      </div>
      <div class="fr-messages-group" id="bloc-error">
        <p class="fr-message fr-message--error">« bloc » doit contenir au minimum 2 élément(s)</p>
      </div>
    `;
    document.body.appendChild(fieldset);
    await nextFrame();
  };

  beforeEach(() => {
    application = Application.start();
    application.register('repetition-limits', RepetitionLimitsController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  test('keeps the error rendered by the server on load', async () => {
    await mount(2);

    expect(fieldset.classList.contains('fr-fieldset--error')).toBe(true);
    expect(errorMessage().textContent).toContain('au minimum 2');
  });

  test('keeps the error while the minimum is not reached', async () => {
    await mount(0);
    await addRow();

    expect(fieldset.classList.contains('fr-fieldset--error')).toBe(true);
    expect(errorMessage().textContent).toContain('au minimum 2');
  });

  test('clears the error once a new row reaches the minimum', async () => {
    await mount(1);
    await addRow();

    expect(fieldset.classList.contains('fr-fieldset--error')).toBe(false);
    expect(errorMessage().textContent?.trim()).toBe('');
  });
});
