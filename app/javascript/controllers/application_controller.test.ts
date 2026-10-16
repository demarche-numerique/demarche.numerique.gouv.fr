import { Application } from '@hotwired/stimulus';
import { afterEach, beforeEach, expect, suite, test } from 'vite-plus/test';

import { ApplicationController } from './application_controller';

class TestController extends ApplicationController {
  clickCount = 0;
  debouncedCount = 0;

  connect(): void {
    this.on('click', () => {
      this.clickCount++;
    });
  }

  scheduleDebounced(interval: number): void {
    this.debounce(this.debouncedFn, interval);
  }

  cancelDebounced(): void {
    this.cancelDebounce(this.debouncedFn);
  }

  private debouncedFn(): void {
    this.debouncedCount++;
  }
}

const nextFrame = () => new Promise(requestAnimationFrame);
const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

suite('ApplicationController', () => {
  let application: Application;
  let element: HTMLElement;

  const getController = () =>
    application.getControllerForElementAndIdentifier(
      element,
      'test'
    ) as TestController;

  beforeEach(async () => {
    application = Application.start();
    application.register('test', TestController);
    element = document.createElement('div');
    element.setAttribute('data-controller', 'test');
    document.body.appendChild(element);
    await nextFrame();
  });

  afterEach(() => {
    element.remove();
    application.stop();
  });

  test('on() removes listeners on disconnect', async () => {
    const controller = getController();

    element.dispatchEvent(new Event('click'));
    expect(controller.clickCount).toEqual(1);

    element.remove();
    await nextFrame();

    element.dispatchEvent(new Event('click'));
    expect(controller.clickCount).toEqual(1);
  });

  test('on() does not stack listeners across reconnects', async () => {
    element.remove();
    await nextFrame();
    document.body.appendChild(element);
    await nextFrame();

    const controller = getController();
    controller.clickCount = 0;
    element.dispatchEvent(new Event('click'));
    expect(controller.clickCount).toEqual(1);
  });

  test('pending debounce is cancelled on disconnect', async () => {
    const controller = getController();

    controller.scheduleDebounced(10);
    element.remove();
    await nextFrame();
    await wait(30);

    expect(controller.debouncedCount).toEqual(0);
  });

  test('debounced function runs and dispatches debounced:empty', async () => {
    const controller = getController();

    let emptyCount = 0;
    const onEmpty = () => emptyCount++;
    document.documentElement.addEventListener('debounced:empty', onEmpty);

    controller.scheduleDebounced(10);
    await wait(30);

    expect(controller.debouncedCount).toEqual(1);
    expect(emptyCount).toEqual(1);

    document.documentElement.removeEventListener('debounced:empty', onEmpty);
  });

  test('cancelDebounce cancels and dispatches debounced:empty', async () => {
    const controller = getController();

    let emptyCount = 0;
    const onEmpty = () => emptyCount++;
    document.documentElement.addEventListener('debounced:empty', onEmpty);

    controller.scheduleDebounced(10);
    controller.cancelDebounced();
    expect(emptyCount).toEqual(1);

    await wait(30);
    expect(controller.debouncedCount).toEqual(0);

    document.documentElement.removeEventListener('debounced:empty', onEmpty);
  });
});
