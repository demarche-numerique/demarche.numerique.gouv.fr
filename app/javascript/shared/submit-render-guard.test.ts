import type { TurboSubmitEndEvent } from '@hotwired/turbo';
import { afterEach, beforeEach, expect, suite, test } from 'vitest';

import { SubmitRenderGuard } from './submit-render-guard';

suite('SubmitRenderGuard', () => {
  let form: HTMLFormElement;
  let insideButton: HTMLButtonElement;
  let outsideButton: HTMLButtonElement;
  let guard: SubmitRenderGuard;

  const submitEnd = (detail: Record<string, unknown>) =>
    new CustomEvent('turbo:submit-end', {
      detail: { formSubmission: { formElement: form }, ...detail }
    }) as unknown as TurboSubmitEndEvent;

  const redirect = { redirected: true };

  // Reports whether a submit event reaches the form's own (bubbling) listener,
  // which is where Turbo picks it up. The listener prevents the default: Firefox
  // performs a real submission on a synthetic submit event and would navigate
  // the test page away.
  const submit = () => {
    let reached = false;
    const listener = (event: Event) => {
      reached = true;
      event.preventDefault();
    };
    form.addEventListener('submit', listener);
    form.dispatchEvent(
      new Event('submit', { cancelable: true, bubbles: true })
    );
    form.removeEventListener('submit', listener);
    return reached;
  };

  beforeEach(() => {
    form = document.createElement('form');
    form.id = 'guarded-form';
    insideButton = document.createElement('button');
    insideButton.type = 'submit';
    form.append(insideButton);
    outsideButton = document.createElement('button');
    outsideButton.type = 'submit';
    outsideButton.setAttribute('form', form.id);
    document.body.append(form, outsideButton);
    guard = new SubmitRenderGuard();
  });

  afterEach(() => {
    form.remove();
    outsideButton.remove();
  });

  test('locks the form until the page is rendered', () => {
    guard.submitEnded(submitEnd({ success: true, fetchResponse: redirect }));

    expect(insideButton.disabled).toBe(true);
    expect(outsideButton.disabled).toBe(true);
    expect(submit()).toBe(false);

    guard.rendered();

    expect(insideButton.disabled).toBe(false);
    expect(outsideButton.disabled).toBe(false);
    expect(submit()).toBe(true);
  });

  test('leaves a button that was already disabled alone', () => {
    outsideButton.disabled = true;

    guard.submitEnded(submitEnd({ success: true, fetchResponse: redirect }));
    guard.rendered();

    expect(outsideButton.disabled).toBe(true);
    expect(insideButton.disabled).toBe(false);
  });

  test('ignores failed submissions', () => {
    guard.submitEnded(submitEnd({ success: false, fetchResponse: redirect }));

    expect(insideButton.disabled).toBe(false);
    expect(submit()).toBe(true);
  });

  test('ignores responses rendered in place, such as turbo streams', () => {
    guard.submitEnded(
      submitEnd({ success: true, fetchResponse: { redirected: false } })
    );

    expect(insideButton.disabled).toBe(false);
    expect(submit()).toBe(true);
  });
});
