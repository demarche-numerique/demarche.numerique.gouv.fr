import { afterEach, beforeEach, expect, suite, test, vi } from 'vitest';

import ProgressBar from './progress-bar';

const ID = 'test-id';

function setupDom() {
  document.body.innerHTML = `
    <template id="progress-bar-template">
      <div class="direct-upload">
        <div class="direct-upload__progress"></div>
        <slot name="filename"></slot>
      </div>
    </template>
    <div class="attachment-field">
      <input type="file" />
      <div data-progress-container></div>
    </div>
  `;
  return document.querySelector<HTMLInputElement>('input')!;
}

function progressBarElement() {
  return document.querySelector(`#direct-upload-${ID}`);
}

suite('ProgressBar minimum display time', () => {
  let input: HTMLInputElement;

  beforeEach(() => {
    input = setupDom();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    document.body.innerHTML = '';
  });

  test('keeps the progress bar visible for at least 1.5s when the upload finishes sooner', () => {
    const file = new File(['x'], 'doc.pdf');
    const bar = new ProgressBar(input, ID, file);
    expect(progressBarElement()).not.toBeNull();

    // Upload finished almost immediately
    bar.destroy();
    expect(progressBarElement()).not.toBeNull();

    vi.advanceTimersByTime(1499);
    expect(progressBarElement()).not.toBeNull();

    vi.advanceTimersByTime(1);
    expect(progressBarElement()).toBeNull();
  });

  test('removes the progress bar immediately when it has already been visible for 1.5s', () => {
    const file = new File(['x'], 'doc.pdf');
    const bar = new ProgressBar(input, ID, file);

    vi.advanceTimersByTime(1500);
    bar.destroy();

    expect(progressBarElement()).toBeNull();
  });
});
