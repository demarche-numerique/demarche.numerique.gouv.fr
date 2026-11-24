import { getConfig } from '@utils';

import { matomoAddressOverrides } from './prefilled-identity';

const {
  matomo: { cookieDomain, domain, enabled, host, key }
} = getConfig();

declare const window: Window &
  typeof globalThis & { _paq: [key: string, value: unknown] };

if (enabled) {
  window._paq = window._paq || [];

  const jsUrl = `//${host}/piwik.js`;
  const trackerUrl = `//${host}/piwik.php`;

  //
  // Configure Matomo analytics
  //

  window._paq.push(['setCookieDomain', cookieDomain]);
  window._paq.push(['setDomains', [domain]]);
  // Don’t store any cookies or send any tracking request when the "Do Not Track" browser setting is enabled.
  window._paq.push(['setDoNotTrack', true]);
  // When enabling external link tracking, consider that it will also report links to attachments.
  // You’ll want to exclude links to attachments from being tracked – for instance using Matomo's
  // `setCustomRequestProcessing` callback.
  // window._paq.push(['enableLinkTracking']);
  // The name a prefill link carries stays out of the statistics, both on the
  // page it opens and on the next one, which reports it as its referrer.
  window._paq.push(
    ...matomoAddressOverrides(window.location.href, document.referrer)
  );
  window._paq.push(['trackPageView']);

  // Load script from Matomo
  window._paq.push(['setTrackerUrl', trackerUrl]);
  window._paq.push(['setSiteId', key]);

  const script = document.createElement('script');
  const firstScript = document.getElementsByTagName('script')[0];
  script.type = 'text/javascript';
  script.id = 'matomo-js';
  script.async = true;
  script.src = jsUrl;
  firstScript.parentNode?.insertBefore(script, firstScript);
}
