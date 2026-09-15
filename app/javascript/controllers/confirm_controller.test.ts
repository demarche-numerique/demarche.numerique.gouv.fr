import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test, vi } from 'vitest';

import { ConfirmController } from './confirm_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

suite('ConfirmController', () => {
  let application: Application;
  let link: HTMLAnchorElement;

  beforeEach(async () => {
    application = Application.start();
    application.register('confirm', ConfirmController);
    link = document.createElement('a');
    link.href = '#somewhere';
    link.setAttribute('data-controller', 'confirm');
    link.setAttribute('data-confirm-message-value', 'Sure?');
    link.setAttribute('data-action', 'confirm#ask');
    document.body.appendChild(link);
    await nextFrame();
  });

  afterEach(() => {
    link.remove();
    application.stop();
    vi.restoreAllMocks();
  });

  test('lets the click through when confirmed', () => {
    const confirm = vi.spyOn(window, 'confirm').mockReturnValue(true);
    const event = new MouseEvent('click', { bubbles: true, cancelable: true });

    link.dispatchEvent(event);

    expect(confirm).toHaveBeenCalledWith('Sure?');
    expect(event.defaultPrevented).toBe(false);
  });

  test('cancels the click when declined', () => {
    vi.spyOn(window, 'confirm').mockReturnValue(false);
    const event = new MouseEvent('click', { bubbles: true, cancelable: true });

    link.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
  });
});
