import type { ErrorEvent, EventHint, Exception } from '@sentry/browser';
import { expect, suite, test } from 'vite-plus/test';

import { ResponseError } from '@utils';
import { shouldDropEvent } from './sentry-filters';

const BUNDLE =
  'https://demarche.numerique.gouv.fr/vite/assets/application-Dzly1LPZ.js';
const PAGE = 'https://demarche.numerique.gouv.fr/dossiers/31128634/merci';

function errorEvent(
  exception: Partial<Exception>,
  { handled = false }: { handled?: boolean } = {}
): ErrorEvent {
  return {
    type: undefined,
    exception: {
      values: [
        {
          type: 'Error',
          value: 'boom',
          mechanism: { type: 'onerror', handled },
          ...exception
        }
      ]
    }
  };
}

function frames(...filenames: (string | undefined)[]) {
  return { frames: filenames.map((filename) => ({ filename })) };
}

const noHint: EventHint = {};

suite('shouldDropEvent', () => {
  test('keeps errors captured explicitly, even without a stacktrace', () => {
    expect(
      shouldDropEvent(
        errorEvent({ stacktrace: undefined }, { handled: true }),
        noHint
      )
    ).toBe(false);
  });

  test('keeps unhandled errors thrown from our bundle', () => {
    expect(
      shouldDropEvent(
        errorEvent({ stacktrace: frames(BUNDLE, BUNDLE) }),
        noHint
      )
    ).toBe(false);
  });

  test('keeps unhandled errors whose throw site is in our bundle under native frames', () => {
    expect(
      shouldDropEvent(
        errorEvent({
          stacktrace: frames(BUNDLE, '[native code]', '<anonymous>')
        }),
        noHint
      )
    ).toBe(false);
  });

  test('drops unhandled errors without a stacktrace', () => {
    expect(shouldDropEvent(errorEvent({ stacktrace: undefined }), noHint)).toBe(
      true
    );
    expect(
      shouldDropEvent(errorEvent({ stacktrace: { frames: [] } }), noHint)
    ).toBe(true);
  });

  test('drops unhandled errors that only have opaque frames', () => {
    expect(
      shouldDropEvent(
        errorEvent({
          value: 'Ka`prod',
          stacktrace: frames('[native code]', '[native code]')
        }),
        noHint
      )
    ).toBe(true);
    expect(
      shouldDropEvent(
        errorEvent({
          value: 'l4S is not defined',
          stacktrace: frames('<anonymous>', undefined)
        }),
        noHint
      )
    ).toBe(true);
    expect(
      shouldDropEvent(errorEvent({ stacktrace: frames('undefined') }), noHint)
    ).toBe(true);
  });

  test('drops unhandled errors thrown from the page itself or a foreign script', () => {
    expect(
      shouldDropEvent(errorEvent({ stacktrace: frames(PAGE) }), noHint)
    ).toBe(true);
    expect(
      shouldDropEvent(
        errorEvent({ stacktrace: frames('chrome-extension://abc/content.js') }),
        noHint
      )
    ).toBe(true);
  });

  test('judges by the throw site, not by wrapper frames from our bundle', () => {
    // Sentry's setInterval instrumentation wraps a callback injected by a proxy.
    expect(
      shouldDropEvent(
        errorEvent({ stacktrace: frames(BUNDLE, PAGE, '[native code]') }),
        noHint
      )
    ).toBe(true);
  });

  test('keeps failures to load one of our chunks even without frames', () => {
    expect(
      shouldDropEvent(
        errorEvent({
          type: 'TypeError',
          value: 'Importing a module script failed.'
        }),
        noHint
      )
    ).toBe(false);
    expect(
      shouldDropEvent(
        errorEvent({
          type: 'TypeError',
          value: `error loading dynamically imported module: ${BUNDLE}`,
          stacktrace: frames(PAGE)
        }),
        noHint
      )
    ).toBe(false);
  });

  suite('with a ResponseError', () => {
    const event = errorEvent({ stacktrace: frames(BUNDLE) });

    test('drops unhandled network failures', () => {
      const error = new ResponseError(
        Response.error(),
        ['Failed to fetch'],
        true
      );
      expect(shouldDropEvent(event, { originalException: error })).toBe(true);
    });

    test('drops unhandled 5xx responses', () => {
      const error = new ResponseError(new Response(null, { status: 503 }));
      expect(shouldDropEvent(event, { originalException: error })).toBe(true);
    });

    test('keeps unhandled 4xx responses', () => {
      const error = new ResponseError(new Response(null, { status: 422 }));
      expect(shouldDropEvent(event, { originalException: error })).toBe(false);
    });

    test('keeps 5xx responses captured explicitly', () => {
      const error = new ResponseError(new Response(null, { status: 503 }));
      const handled = errorEvent(
        { stacktrace: frames(BUNDLE) },
        { handled: true }
      );
      expect(shouldDropEvent(handled, { originalException: error })).toBe(
        false
      );
    });
  });
});
