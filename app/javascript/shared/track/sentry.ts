import * as Sentry from '@sentry/browser';
import { getConfig } from '@utils';

import { shouldDropEvent } from './sentry-filters';

const {
  sentry: { key, enabled, user, environment, browser, release }
} = getConfig();

// We need to check for key presence here as we do not have a dsn for browser yet
if (enabled && key) {
  Sentry.init({
    dsn: key,
    release: release ?? undefined,
    environment: environment ?? undefined,
    tracesSampleRate: 0.1,
    // Extensions and in-app browser bridges: not our code, never fixable.
    denyUrls: [
      /^chrome(-extension)?:\/\//i,
      /^moz-extension:\/\//i,
      /^safari(-web)?-extension:\/\//i,
      /^ms-browser-extension:\/\//i,
      /^iabjs:\/\//i,
      /^file:\/\//i
    ],
    ignoreErrors: [
      // Promises rejected with something that is not an Error (events, plain
      // objects…): a Microsoft crawler and various injected scripts do that,
      // our code does not.
      // See https://forum.sentry.io/t/unhandledrejection-non-error-promise-rejection-captured-with-value/14062
      /captured as promise rejection/,
      'Non-error promise rejection captured with keys',
      'Non-Error promise rejection captured with value',

      // Error with password input with a password manager, pending a DSFR fix
      'e.getModifierState is not a function',

      // Piwik/Matomo invasive error
      "'get' on proxy: property 'javaEnabled' is a read-only and non-configurable data property on the proxy target but the proxy did not return its actual value",

      // La gaufre script often triggers an error while loading other dependencies
      'NetworkError when attempting to fetch resource. (static.suite.anct.gouv.fr)'
    ],
    // Unhandled errors that did not originate in our bundles, and requests
    // that failed for availability reasons: see sentry-filters.ts.
    beforeSend(event, hint) {
      return shouldDropEvent(event, hint) ? null : event;
    }
  });

  const scope = Sentry.getCurrentScope();
  scope.setUser(user);
  scope.setExtra('browser', browser.modern ? 'modern' : 'legacy');

  // Register a way to explicitely capture messages from a different bundle.
  addEventListener('sentry:capture-exception', (event) => {
    const error = (event as CustomEvent).detail;
    Sentry.captureException(error);
  });
}
