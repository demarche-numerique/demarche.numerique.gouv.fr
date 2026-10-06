import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test } from 'vitest';

import { RepetitionLimitsController } from './repetition_limits_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

suite('RepetitionLimitsController', () => {
  let application: Application;
  let fieldset: HTMLFieldSetElement;

  const errorMessage = () =>
    fieldset.querySelector('#bloc-error') as HTMLElement;

  const dispatchMinReached = async (errorId: string) => {
    document.documentElement.dispatchEvent(
      new CustomEvent('repetition:min-reached', {
        bubbles: true,
        detail: { error_id: errorId }
      })
    );
    await nextFrame();
  };

  beforeEach(async () => {
    application = Application.start();
    application.register('repetition-limits', RepetitionLimitsController);

    fieldset = document.createElement('fieldset');
    fieldset.className = 'fr-fieldset fr-fieldset--error';
    fieldset.innerHTML = `
      <div
        data-controller="repetition-limits"
        data-action="repetition:min-reached@document->repetition-limits#clear"
        data-repetition-limits-error-id-value="bloc-error"
      ></div>
      <div class="fr-messages-group" id="bloc-error">
        <p class="fr-message fr-message--error">« bloc » doit contenir au minimum 2 élément(s)</p>
      </div>
    `;
    document.body.appendChild(fieldset);
    await nextFrame();
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  test('clears the error of its block once the minimum is reached', async () => {
    await dispatchMinReached('bloc-error');

    expect(fieldset.classList.contains('fr-fieldset--error')).toBe(false);
    expect(errorMessage().textContent?.trim()).toBe('');
  });

  test('ignores the minimum reached by another block', async () => {
    await dispatchMinReached('other-bloc-error');

    expect(fieldset.classList.contains('fr-fieldset--error')).toBe(true);
    expect(errorMessage().textContent).toContain('au minimum 2');
  });
});
