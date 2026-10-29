import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test, vi } from 'vitest';

import { CountdownButtonController } from './countdown_button_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

suite('CountdownButtonController', () => {
  let application: Application;
  let element: HTMLElement;

  const mount = async (seconds: number) => {
    element = document.createElement('div');
    element.setAttribute('data-controller', 'countdown-button');
    element.setAttribute(
      'data-action',
      'visibilitychange@document->countdown-button#refresh pageshow@window->countdown-button#restore'
    );
    element.setAttribute(
      'data-countdown-button-seconds-value',
      String(seconds)
    );
    element.setAttribute(
      'data-countdown-button-one-value',
      'Renvoyer (1 seconde)'
    );
    element.setAttribute(
      'data-countdown-button-other-value',
      'Renvoyer (# secondes)'
    );
    element.setAttribute('data-countdown-button-label-value', 'Renvoyer');
    element.setAttribute(
      'data-countdown-button-available-value',
      'Vous pouvez maintenant renvoyer.'
    );
    element.innerHTML = `
      <button type="submit" data-countdown-button-target="button">Texte serveur</button>
      <p class="fr-sr-only" role="status" data-countdown-button-target="status"></p>
    `;
    document.body.appendChild(element);
    await nextFrame();
    return {
      button: element.querySelector('button') as HTMLButtonElement,
      status: element.querySelector('[role="status"]') as HTMLElement,
      controller: application.getControllerForElementAndIdentifier(
        element,
        'countdown-button'
      ) as CountdownButtonController
    };
  };

  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'Date'] });
    application = Application.start();
    application.register('countdown-button', CountdownButtonController);
  });

  afterEach(() => {
    vi.useRealTimers();
    element.remove();
    document.head.querySelector('meta[name="turbo-cache-control"]')?.remove();
    application.stop();
    vi.restoreAllMocks();
  });

  test('counts down each second, in the singular at one second', async () => {
    const { button, status } = await mount(3);
    expect(button.disabled).toBe(true);
    expect(button.textContent).toBe('Renvoyer (3 secondes)');
    vi.advanceTimersByTime(1000);
    expect(button.textContent).toBe('Renvoyer (2 secondes)');
    vi.advanceTimersByTime(1000);
    expect(button.textContent).toBe('Renvoyer (1 seconde)');
    expect(status.textContent).toBe('');
  });

  test('enables the button and announces it once', async () => {
    const { button, status } = await mount(2);
    vi.advanceTimersByTime(2000);
    expect(button.disabled).toBe(false);
    expect(button.textContent).toBe('Renvoyer');
    expect(status.textContent).toBe('Vous pouvez maintenant renvoyer.');
    expect(vi.getTimerCount()).toBe(0);
    status.textContent = '';
    document.dispatchEvent(new Event('visibilitychange'));
    expect(status.textContent).toBe('');
  });

  test('leaves an enabled button alone', async () => {
    const { button, status } = await mount(0);
    expect(button.disabled).toBe(false);
    expect(button.textContent).toBe('Texte serveur');
    expect(status.textContent).toBe('');
    expect(vi.getTimerCount()).toBe(0);
  });

  test('shows the real remaining time after the page was suspended', async () => {
    const { button } = await mount(120);
    vi.advanceTimersByTime(10_000);
    expect(button.textContent).toBe('Renvoyer (110 secondes)');
    vi.setSystemTime(Date.now() + 90_000);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(button.textContent).toBe('Renvoyer (20 secondes)');
  });

  test.each([0, 120])(
    'keeps the page out of the Turbo cache, with %i seconds left',
    async (seconds) => {
      await mount(seconds);
      const meta = document.head.querySelector(
        'meta[name="turbo-cache-control"]'
      );
      expect(meta?.getAttribute('content')).toBe('no-cache');
    }
  );

  test('reloads the page when the browser restores it from its cache', async () => {
    const { controller } = await mount(0);
    const reload = vi
      .spyOn(controller, 'reloadPage')
      .mockImplementation(() => {});
    window.dispatchEvent(
      new PageTransitionEvent('pageshow', { persisted: false })
    );
    expect(reload).not.toHaveBeenCalled();
    window.dispatchEvent(
      new PageTransitionEvent('pageshow', { persisted: true })
    );
    expect(reload).toHaveBeenCalledOnce();
  });

  test('never enables the button before the delay is over', async () => {
    const { button } = await mount(3);
    vi.advanceTimersByTime(2000);
    vi.setSystemTime(Date.now() + 500);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(button.disabled).toBe(true);
    expect(button.textContent).toBe('Renvoyer (1 seconde)');
  });

  test('stops counting when the element leaves the page', async () => {
    await mount(120);
    expect(vi.getTimerCount()).toBe(1);
    element.remove();
    await nextFrame();
    expect(vi.getTimerCount()).toBe(0);
  });
});
