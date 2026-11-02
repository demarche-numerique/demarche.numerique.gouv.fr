import '@ungap/with-resolvers';
import { expect, suite, test } from 'vite-plus/test';

import { initNextDelay, startPolling } from './polling';

suite('polling', () => {
  test('startPolling', async () => {
    let count = 0;
    const { promise, resolve } = Promise.withResolvers();
    const cb = async () => {
      count++;
      if (count == 2) {
        resolve(undefined);
      }
    };
    const stop = startPolling(cb, { baseDelay: 10 });

    await promise;
    expect(count).toEqual(2);

    stop();
  });

  test('startPolling [default]', () => {
    const nextDelay = initNextDelay({});
    expect(nextDelay()).toEqual(1000);
    expect(nextDelay()).toEqual(1000);
    expect(nextDelay()).toEqual(1000);
    expect(nextDelay()).toEqual(1000);
  });

  test('startPolling [jitter]', () => {
    const nextDelay = initNextDelay({ jitter: true });
    expect(nextDelay()).toBeGreaterThanOrEqual(1000);
    expect(nextDelay()).toBeGreaterThanOrEqual(1000);
    expect(nextDelay()).toBeGreaterThanOrEqual(1000);
    expect(nextDelay()).toBeGreaterThanOrEqual(1000);
  });

  test('startPolling [fixed]', () => {
    const nextDelay = initNextDelay({ baseDelay: 10, maxAttempts: 4 });
    expect(nextDelay()).toEqual(10);
    expect(nextDelay()).toEqual(10);
    expect(nextDelay()).toEqual(10);
    expect(nextDelay()).toEqual(10);
    expect(nextDelay()).toEqual(0);
    expect(nextDelay()).toEqual(0);
  });

  test('startPolling [fibonacci]', () => {
    const nextDelay = initNextDelay({ strategy: 'fibonacci', maxAttempts: 10 });
    expect(nextDelay()).toEqual(1000);
    expect(nextDelay()).toEqual(2000);
    expect(nextDelay()).toEqual(3000);
    expect(nextDelay()).toEqual(5000);
    expect(nextDelay()).toEqual(8000);
    expect(nextDelay()).toEqual(13000);
    expect(nextDelay()).toEqual(21000);
    expect(nextDelay()).toEqual(30000);
    expect(nextDelay()).toEqual(30000);
    expect(nextDelay()).toEqual(30000);
    expect(nextDelay()).toEqual(0);
  });

  test('startPolling [exponential]', () => {
    const nextDelay = initNextDelay({ strategy: 'exponential' });
    expect(nextDelay()).toEqual(2000);
    expect(nextDelay()).toEqual(4000);
    expect(nextDelay()).toEqual(8000);
    expect(nextDelay()).toEqual(16000);
    expect(nextDelay()).toEqual(30000);
    expect(nextDelay()).toEqual(30000);
  });
});
