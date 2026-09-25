import { beforeEach, expect, suite, test } from 'vitest';

import { fetchResponded, pageShown } from './session-expiry';

suite('session expiry', () => {
  const fetchResponse = (
    status: number,
    signInPath: string | null = '/users/sign_in'
  ) =>
    new CustomEvent('turbo:before-fetch-response', {
      cancelable: true,
      detail: {
        fetchResponse: {
          response: {
            status,
            headers: {
              get: (name: string) =>
                name === 'X-Sign-In-Path' ? signInPath : null
            }
          }
        }
      }
    });

  let destinations: string[];
  const navigate = (destination: string) => destinations.push(destination);

  beforeEach(() => {
    destinations = [];
    // The module keeps one flag across events, and this is how a document that
    // comes back lowers it.
    pageShown();
  });

  test('leaves anything but a 401 to Turbo', () => {
    const event = fetchResponse(500);

    fetchResponded(event, navigate);

    expect(event.defaultPrevented).toBe(false);
    expect(destinations).toEqual([]);
  });

  test('leaves a 401 carrying no sign in path to Turbo', () => {
    const event = fetchResponse(401, null);

    fetchResponded(event, navigate);

    expect(event.defaultPrevented).toBe(false);
    expect(destinations).toEqual([]);
  });

  test('refuses to send the browser to another origin', () => {
    const event = fetchResponse(401, 'https://evil.example.org/users/sign_in');

    fetchResponded(event, navigate);

    expect(event.defaultPrevented).toBe(false);
    expect(destinations).toEqual([]);
  });

  test('navigates once for a page whose frames all fail', () => {
    const first = fetchResponse(401);
    const second = fetchResponse(401);

    fetchResponded(first, navigate);
    fetchResponded(second, navigate);

    expect(first.defaultPrevented).toBe(true);
    expect(second.defaultPrevented).toBe(true);
    expect(destinations).toHaveLength(1);
  });

  // Without the pageshow listener the flag stays raised through a bfcache
  // restore, and every later 401 is cancelled and then dropped.
  test('navigates again once the document has come back', () => {
    fetchResponded(fetchResponse(401), navigate);
    expect(destinations).toHaveLength(1);

    pageShown();
    fetchResponded(fetchResponse(401), navigate);

    expect(destinations).toHaveLength(2);
  });
});
