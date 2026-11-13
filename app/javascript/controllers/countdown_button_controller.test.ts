import { Application } from '@hotwired/stimulus';
import { page } from '@vitest/browser/context';
import { afterEach, beforeEach, expect, suite, test, vi } from 'vitest';

import { CountdownButtonController } from './countdown_button_controller';

const nextFrame = () => new Promise(requestAnimationFrame);

const accessibleButton = (name: string) =>
  page.getByRole('button', { name, exact: true }).query();

suite('CountdownButtonController', () => {
  let application: Application;
  let element: HTMLElement;

  const mount = async (seconds: number, { checked = false } = {}) => {
    element = document.createElement('div');
    element.setAttribute('data-controller', 'countdown-button');
    element.setAttribute(
      'data-action',
      'visibilitychange@document->countdown-button#refresh pageshow@window->countdown-button#restore'
    );
    Object.entries({
      seconds: String(seconds),
      'counter-one': '(1 seconde)',
      'counter-other': '(# secondes)',
      'announcement-one': 'Renvoi possible dans 1 seconde.',
      'announcement-other': 'Renvoi possible dans # secondes.',
      available: 'Vous pouvez maintenant renvoyer.'
    }).forEach(([name, value]) =>
      element.setAttribute(`data-countdown-button-${name}-value`, value)
    );
    element.innerHTML = `
      <button type="submit" data-countdown-button-target="button"><span>Renvoyer<span aria-hidden="true" data-countdown-button-target="counter"></span></span></button>
      <div class="fr-hidden" data-countdown-button-target="toggle">
        <input type="checkbox" id="hide-countdown" ${checked ? 'checked' : ''} data-countdown-button-target="checkbox" data-action="change->countdown-button#toggleCounter">
        <label for="hide-countdown">Masquer</label>
      </div>
      <p class="fr-sr-only" role="status" data-countdown-button-target="status"></p>
    `;
    document.body.appendChild(element);
    await nextFrame();
    return {
      button: element.querySelector('button') as HTMLButtonElement,
      counter: element.querySelector(
        '[data-countdown-button-target="counter"]'
      ) as HTMLElement,
      status: element.querySelector('[role="status"]') as HTMLElement,
      toggle: element.querySelector(
        '[data-countdown-button-target="toggle"]'
      ) as HTMLElement,
      checkbox: element.querySelector(
        'input[type="checkbox"]'
      ) as HTMLInputElement,
      controller: application.getControllerForElementAndIdentifier(
        element,
        'countdown-button'
      ) as CountdownButtonController
    };
  };

  let clock = 0;

  const receivedResponseAgo = (milliseconds: number) => {
    clock += 1_000_000;
    vi.spyOn(performance, 'now').mockReturnValue(clock);
    vi.spyOn(performance, 'getEntriesByType').mockReturnValue([
      { responseStart: clock - milliseconds } as PerformanceNavigationTiming
    ]);
  };

  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'Date'] });
    receivedResponseAgo(0);
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

  test('counts down each second in a counter hidden from screen readers', async () => {
    const { button, counter } = await mount(3);
    expect(button.disabled).toBe(true);
    expect(counter.textContent).toBe(' (3 secondes)');
    expect(accessibleButton('Renvoyer')).toBe(button);
    vi.advanceTimersByTime(1000);
    expect(counter.textContent).toBe(' (2 secondes)');
    vi.advanceTimersByTime(1000);
    expect(counter.textContent).toBe(' (1 seconde)');
    expect(accessibleButton('Renvoyer')).toBe(button);
  });

  test('announces the remaining time one second after arrival, then every 30 seconds', async () => {
    const { status } = await mount(119);
    expect(status.textContent).toBe('');
    vi.advanceTimersByTime(1_000);
    expect(status.textContent).toBe('Renvoi possible dans 118 secondes.');
    vi.advanceTimersByTime(27_000);
    expect(status.textContent).toBe('Renvoi possible dans 118 secondes.');
    vi.advanceTimersByTime(1_000);
    expect(status.textContent).toBe('Renvoi possible dans 90 secondes.');
    vi.advanceTimersByTime(29_000);
    expect(status.textContent).toBe('Renvoi possible dans 90 secondes.');
    vi.advanceTimersByTime(1_000);
    expect(status.textContent).toBe('Renvoi possible dans 60 secondes.');
    vi.advanceTimersByTime(30_000);
    expect(status.textContent).toBe('Renvoi possible dans 30 secondes.');
    vi.advanceTimersByTime(29_000);
    expect(status.textContent).toBe('Renvoi possible dans 30 secondes.');
  });

  test('announces a step reached on the first tick only once', async () => {
    const { status } = await mount(91);
    expect(status.textContent).toBe('');
    vi.advanceTimersByTime(1_000);
    expect(status.textContent).toBe('Renvoi possible dans 90 secondes.');
    vi.advanceTimersByTime(1_000);
    expect(status.textContent).toBe('Renvoi possible dans 90 secondes.');
  });

  test('announces in the singular with one second left', async () => {
    const { counter, status } = await mount(2);
    vi.advanceTimersByTime(1_000);
    expect(counter.textContent).toBe(' (1 seconde)');
    expect(status.textContent).toBe('Renvoi possible dans 1 seconde.');
  });

  test('enables the button and announces it once', async () => {
    const { button, counter, status } = await mount(2);
    vi.advanceTimersByTime(2000);
    expect(button.disabled).toBe(false);
    expect(counter.textContent).toBe('');
    expect(accessibleButton('Renvoyer')).toBe(button);
    expect(status.textContent).toBe('Vous pouvez maintenant renvoyer.');
    expect(vi.getTimerCount()).toBe(0);
    status.textContent = '';
    document.dispatchEvent(new Event('visibilitychange'));
    expect(status.textContent).toBe('');
  });

  test('leaves an enabled button alone', async () => {
    const { button, counter, status, toggle } = await mount(0);
    expect(button.disabled).toBe(false);
    expect(counter.textContent).toBe('');
    expect(status.textContent).toBe('');
    expect(toggle.classList.contains('fr-hidden')).toBe(true);
    expect(vi.getTimerCount()).toBe(0);
  });

  test('lets the user hide and show the counter while it counts down', async () => {
    const { button, counter, toggle, checkbox } = await mount(3);
    expect(toggle.classList.contains('fr-hidden')).toBe(false);
    expect(counter.classList.contains('fr-hidden')).toBe(false);
    checkbox.click();
    expect(counter.classList.contains('fr-hidden')).toBe(true);
    vi.advanceTimersByTime(1000);
    expect(counter.classList.contains('fr-hidden')).toBe(true);
    expect(button.disabled).toBe(true);
    expect(accessibleButton('Renvoyer')).toBe(button);
    checkbox.click();
    expect(counter.classList.contains('fr-hidden')).toBe(false);
    expect(counter.textContent).toBe(' (2 secondes)');
  });

  test('keeps the counter hidden when the browser restores a ticked box', async () => {
    const { counter } = await mount(3, { checked: true });
    expect(counter.classList.contains('fr-hidden')).toBe(true);
  });

  test('removes the toggle once the delay is over and moves its focus to the resend button', async () => {
    const { button, toggle, checkbox } = await mount(2);
    checkbox.focus();
    vi.advanceTimersByTime(2000);
    expect(toggle.classList.contains('fr-hidden')).toBe(true);
    expect(document.activeElement).toBe(button);
  });

  test('shows and announces the real remaining time after the page was suspended', async () => {
    const { counter, status } = await mount(120);
    vi.advanceTimersByTime(10_000);
    expect(counter.textContent).toBe(' (110 secondes)');
    expect(status.textContent).toBe('Renvoi possible dans 119 secondes.');
    vi.setSystemTime(Date.now() + 90_000);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(counter.textContent).toBe(' (20 secondes)');
    expect(status.textContent).toBe('Renvoi possible dans 20 secondes.');
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
    const { button, counter } = await mount(3);
    vi.advanceTimersByTime(2000);
    vi.setSystemTime(Date.now() + 500);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(button.disabled).toBe(true);
    expect(counter.textContent).toBe(' (1 seconde)');
  });

  test('deducts the time the page took to start the countdown', async () => {
    receivedResponseAgo(1000);
    const { button, counter } = await mount(3);
    expect(button.disabled).toBe(true);
    expect(counter.textContent).toBe(' (2 secondes)');
  });

  test('enables the button right away when the page took longer than the delay to start', async () => {
    receivedResponseAgo(4000);
    const { button, counter } = await mount(3);
    expect(button.disabled).toBe(false);
    expect(counter.textContent).toBe('');
    expect(vi.getTimerCount()).toBe(0);
  });

  test('ignores the time spent on the previous page when Turbo brought this one', async () => {
    receivedResponseAgo(5000);
    document.dispatchEvent(new Event('turbo:before-fetch-response'));
    const { counter } = await mount(120);
    expect(counter.textContent).toBe(' (120 secondes)');
  });

  test('stops counting when the element leaves the page', async () => {
    await mount(120);
    expect(vi.getTimerCount()).toBe(1);
    element.remove();
    await nextFrame();
    expect(vi.getTimerCount()).toBe(0);
  });
});
